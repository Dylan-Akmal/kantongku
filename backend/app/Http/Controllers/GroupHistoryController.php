<?php

namespace App\Http\Controllers;

use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;

class GroupHistoryController extends Controller
{
    public function index(Request $request, string $id): JsonResponse
    {
        $group = $request->user()->groups()
            ->where('split_groups.id', $id)
            ->firstOrFail();

        $request->validate([
            'per_page' => ['nullable', 'integer', 'min:1', 'max:100'],
            'page' => ['nullable', 'integer', 'min:1'],
        ]);

        $expenses = $group->expenses()
            ->with('payer:id,name')
            ->get()
            ->map(fn ($expense) => [
                'type' => 'expense',
                'id' => $expense->id,
                'date' => $expense->expense_date->format('Y-m-d'),
                'title' => $expense->title,
                'amount' => $expense->total_amount,
                'paid_by' => $expense->payer?->only(['id', 'name']),
                'recorded_at' => Carbon::parse($expense->created_at),
            ]);

        $settlements = $group->settlements()
            ->with(['fromUser:id,name', 'toUser:id,name'])
            ->get()
            ->map(fn ($settlement) => [
                'type' => 'settlement',
                'id' => $settlement->id,
                'date' => Carbon::parse($settlement->settled_at)->format('Y-m-d'),
                'from' => $settlement->fromUser?->only(['id', 'name']),
                'to' => $settlement->toUser?->only(['id', 'name']),
                'amount' => $settlement->amount,
                'note' => $settlement->note,
                'recorded_at' => Carbon::parse($settlement->created_at),
            ]);

        $items = $expenses->concat($settlements)
            ->sortByDesc(fn (array $item) => sprintf('%012d-%010d', $item['recorded_at']->timestamp, $item['id']))
            ->values();

        $perPage = $request->integer('per_page', 20);
        $page = $request->integer('page', 1);

        return response()->json([
            'data' => $items->forPage($page, $perPage)->values(),
            'meta' => [
                'current_page' => $page,
                'per_page' => $perPage,
                'total' => $items->count(),
                'last_page' => max(1, (int) ceil($items->count() / $perPage)),
            ],
        ]);
    }
}