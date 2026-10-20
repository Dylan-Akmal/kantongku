<?php

namespace App\Http\Controllers;

use App\Models\User;
use App\Services\GroupBalanceService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class GroupBalanceController extends Controller
{
    public function show(Request $request, string $id, GroupBalanceService $service): JsonResponse
    {
        $group = $request->user()->groups()
            ->where('split_groups.id', $id)
            ->firstOrFail();

        $balances = $service->balances($group);
        $names = User::whereIn('id', array_keys($balances))->pluck('name', 'id');

        $items = collect($balances)
            ->map(fn (int $balance, int $userId) => [
                'user_id' => $userId,
                'name' => $names[$userId] ?? null,
                'balance' => $balance,
            ])
            ->values();

        $settleUp = collect($service->simplify($balances))
            ->map(fn (array $payment) => [
                'from' => ['id' => $payment['from'], 'name' => $names[$payment['from']] ?? null],
                'to' => ['id' => $payment['to'], 'name' => $names[$payment['to']] ?? null],
                'amount' => $payment['amount'],
            ])
            ->values();

        return response()->json([
            'data' => [
                'my_balance' => $balances[$request->user()->id] ?? 0,
                'balances' => $items,
                'settle_up' => $settleUp,
            ],
        ]);
    }
}