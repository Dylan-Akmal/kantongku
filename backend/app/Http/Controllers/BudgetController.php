<?php

namespace App\Http\Controllers;

use App\Models\Budget;
use App\Support\Period;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Validation\Rule;

class BudgetController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $request->validate([
            'month' => ['nullable', 'date_format:Y-m'],
        ]);

        [$start, $end] = Period::month($request->query('month'));
        $user = $request->user();

        $budgets = $user->budgets()
            ->with('category:id,name')
            ->where('month', $start->toDateString())
            ->orderBy('id')
            ->get();

        $spent = $user->transactions()
            ->where('type', 'expense')
            ->whereBetween('transaction_date', [$start->toDateString(), $end->toDateString()])
            ->whereIn('category_id', $budgets->pluck('category_id'))
            ->selectRaw('category_id, SUM(amount) as total')
            ->groupBy('category_id')
            ->pluck('total', 'category_id');

        $items = $budgets
            ->map(fn (Budget $budget) => $this->payload($budget, (int) ($spent[$budget->category_id] ?? 0)))
            ->values();

        return response()->json([
            'data' => $items,
            'meta' => [
                'month' => $start->format('Y-m'),
                'total_budget' => $items->sum('amount'),
                'total_spent' => $items->sum('spent'),
            ],
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $user = $request->user();

        $data = $request->validate([
            'category_id' => [
                'required', 'integer',
                Rule::exists('categories', 'id')->where(
                    fn ($q) => $q->where('user_id', $user->id)->where('type', 'expense')
                ),
            ],
            'month' => ['required', 'date_format:Y-m'],
            'amount' => ['required', 'integer', 'min:1', 'max:999999999999'],
        ]);

        [$start, $end] = Period::month($data['month']);

        $budget = $user->budgets()->updateOrCreate(
            ['category_id' => $data['category_id'], 'month' => $start->toDateString()],
            ['amount' => $data['amount']],
        );

        $budget->load('category:id,name');

        return response()->json([
            'message' => $budget->wasRecentlyCreated
                ? 'Anggaran berhasil dibuat.'
                : 'Anggaran berhasil diperbarui.',
            'data' => $this->payload($budget, $this->spentFor($request, $budget->category_id, $start, $end)),
        ], $budget->wasRecentlyCreated ? 201 : 200);
    }

    public function destroy(Request $request, string $id): JsonResponse
    {
        $request->user()->budgets()->findOrFail($id)->delete();

        return response()->json([
            'message' => 'Anggaran berhasil dihapus.',
        ]);
    }

    private function spentFor(Request $request, int $categoryId, Carbon $start, Carbon $end): int
    {
        return (int) $request->user()->transactions()
            ->where('type', 'expense')
            ->where('category_id', $categoryId)
            ->whereBetween('transaction_date', [$start->toDateString(), $end->toDateString()])
            ->sum('amount');
    }

    private function payload(Budget $budget, int $spent): array
    {
        return [
            'id' => $budget->id,
            'category' => $budget->category?->only(['id', 'name']),
            'month' => $budget->month->format('Y-m'),
            'amount' => $budget->amount,
            'spent' => $spent,
            'remaining' => $budget->amount - $spent,
            'percentage' => $budget->amount > 0 ? round($spent / $budget->amount * 100, 1) : 0,
            'is_over' => $spent > $budget->amount,
        ];
    }
}