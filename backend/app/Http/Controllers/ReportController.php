<?php

namespace App\Http\Controllers;

use App\Support\Period;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\StreamedResponse;

class ReportController extends Controller
{
    public function monthly(Request $request): JsonResponse
    {
        [$start, $end] = $this->period($request);

        $base = $request->user()->transactions()
            ->whereIn('type', ['income', 'expense'])
            ->whereBetween('transaction_date', [$start->toDateString(), $end->toDateString()]);

        $totals = (clone $base)
            ->selectRaw('type, SUM(amount) as total')
            ->groupBy('type')
            ->pluck('total', 'type');

        $income = (int) ($totals['income'] ?? 0);
        $expense = (int) ($totals['expense'] ?? 0);

        $rows = (clone $base)
            ->where('type', 'expense')
            ->selectRaw('category_id, SUM(amount) as total')
            ->groupBy('category_id')
            ->orderByDesc('total')
            ->get();

        $names = $request->user()->categories()
            ->whereIn('id', $rows->pluck('category_id'))
            ->pluck('name', 'id');

        $byCategory = $rows->map(fn ($row) => [
            'category_id' => $row->category_id,
            'name' => $names[$row->category_id] ?? 'Tanpa kategori',
            'total' => (int) $row->total,
            'percentage' => $expense > 0 ? round($row->total / $expense * 100, 1) : 0,
        ])->values();

        return response()->json([
            'data' => [
                'month' => $start->format('Y-m'),
                'total_income' => $income,
                'total_expense' => $expense,
                'net' => $income - $expense,
                'transaction_count' => (clone $base)->count(),
                'expense_by_category' => $byCategory,
            ],
        ]);
    }

    public function daily(Request $request): JsonResponse
    {
        [$start, $end] = $this->period($request);

        $rows = $request->user()->transactions()
            ->whereIn('type', ['income', 'expense'])
            ->whereBetween('transaction_date', [$start->toDateString(), $end->toDateString()])
            ->selectRaw('transaction_date, type, SUM(amount) as total')
            ->groupBy('transaction_date', 'type')
            ->get();

        $days = [];
        for ($day = $start->copy(); $day->lte($end); $day->addDay()) {
            $days[$day->format('Y-m-d')] = [
                'date' => $day->format('Y-m-d'),
                'income' => 0,
                'expense' => 0,
            ];
        }

        foreach ($rows as $row) {
            $days[$row->transaction_date->format('Y-m-d')][$row->type] = (int) $row->total;
        }

        return response()->json([
            'data' => array_values($days),
            'meta' => ['month' => $start->format('Y-m')],
        ]);
    }

    public function export(Request $request): StreamedResponse
    {
        [$start, $end] = $this->period($request);

        $transactions = $request->user()->transactions()
            ->with(['wallet:id,name', 'toWallet:id,name', 'category:id,name'])
            ->whereBetween('transaction_date', [$start->toDateString(), $end->toDateString()])
            ->orderBy('transaction_date')
            ->orderBy('id')
            ->get();

        $labels = ['income' => 'Pemasukan', 'expense' => 'Pengeluaran', 'transfer' => 'Transfer'];

        return response()->streamDownload(function () use ($transactions, $labels) {
            $out = fopen('php://output', 'w');
            fwrite($out, "\xEF\xBB\xBF");
            fputcsv($out, ['Tanggal', 'Tipe', 'Dompet', 'Dompet Tujuan', 'Kategori', 'Nominal', 'Catatan']);

            foreach ($transactions as $t) {
                fputcsv($out, [
                    $t->transaction_date->format('Y-m-d'),
                    $labels[$t->type] ?? $t->type,
                    $t->wallet?->name,
                    $t->toWallet?->name,
                    $t->category?->name,
                    $t->amount,
                    $this->safeCell($t->note),
                ]);
            }

            fclose($out);
        }, 'kantongku-'.$start->format('Y-m').'.csv', [
            'Content-Type' => 'text/csv; charset=UTF-8',
        ]);
    }

    private function period(Request $request): array
    {
        $request->validate([
            'month' => ['nullable', 'date_format:Y-m'],
        ]);

        return Period::month($request->query('month'));
    }

    private function safeCell(?string $value): ?string
    {
        if ($value !== null && $value !== '' && in_array($value[0], ['=', '+', '-', '@'], true)) {
            return "'".$value;
        }

        return $value;
    }
}