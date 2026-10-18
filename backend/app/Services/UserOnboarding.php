<?php

namespace App\Services;

use App\Models\Category;
use App\Models\User;

class UserOnboarding
{
    public const EXPENSE_CATEGORIES = [
        'Makan & Minum',
        'Transportasi',
        'Belanja',
        'Tagihan',
        'Hiburan',
        'Kesehatan',
        'Pendidikan',
        'Lainnya',
    ];

    public const INCOME_CATEGORIES = [
        'Gaji',
        'Bonus',
        'Hadiah',
        'Lainnya',
    ];

    public static function setup(User $user): void
    {
        $now = now();
        $rows = [];

        foreach (self::EXPENSE_CATEGORIES as $name) {
            $rows[] = [
                'user_id' => $user->id,
                'name' => $name,
                'type' => 'expense',
                'created_at' => $now,
                'updated_at' => $now,
            ];
        }

        foreach (self::INCOME_CATEGORIES as $name) {
            $rows[] = [
                'user_id' => $user->id,
                'name' => $name,
                'type' => 'income',
                'created_at' => $now,
                'updated_at' => $now,
            ];
        }

        Category::insert($rows);

        $user->wallets()->create([
            'name' => 'Tunai',
            'type' => 'cash',
            'initial_balance' => 0,
        ]);
    }
}