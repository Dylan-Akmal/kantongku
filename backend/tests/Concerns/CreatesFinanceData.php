<?php

namespace Tests\Concerns;

use App\Models\Category;
use App\Models\Transaction;
use App\Models\User;
use App\Models\Wallet;

trait CreatesFinanceData
{
    protected function wallet(User $user, string $name = 'BCA', int $initialBalance = 0, string $type = 'bank'): Wallet
    {
        return $user->wallets()->create([
            'name' => $name,
            'type' => $type,
            'initial_balance' => $initialBalance,
        ]);
    }

    protected function cashWallet(User $user): Wallet
    {
        return $user->wallets()->where('name', 'Tunai')->firstOrFail();
    }

    protected function category(User $user, string $name, string $type): Category
    {
        return $user->categories()->where('name', $name)->where('type', $type)->firstOrFail();
    }

    protected function addTransaction(User $user, array $attributes): Transaction
    {
        return $user->transactions()->create(array_merge([
            'type' => 'expense',
            'amount' => 10000,
            'transaction_date' => '2026-10-18',
        ], $attributes));
    }
}