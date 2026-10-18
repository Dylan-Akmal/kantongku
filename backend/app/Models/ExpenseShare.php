<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ExpenseShare extends Model
{
    public $timestamps = false;

    protected $fillable = [
        'expense_id',
        'user_id',
        'amount_owed',
    ];

    protected function casts(): array
    {
        return [
            'amount_owed' => 'integer',
        ];
    }

    public function expense(): BelongsTo
    {
        return $this->belongsTo(GroupExpense::class, 'expense_id');
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}