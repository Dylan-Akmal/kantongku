<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class GroupExpense extends Model
{
    use SoftDeletes;

    protected $fillable = [
        'group_id',
        'paid_by',
        'created_by',
        'title',
        'total_amount',
        'split_type',
        'expense_date',
        'note',
    ];

    protected function casts(): array
    {
        return [
            'total_amount' => 'integer',
            'expense_date' => 'date:Y-m-d',
        ];
    }

    public function group(): BelongsTo
    {
        return $this->belongsTo(SplitGroup::class, 'group_id');
    }

    public function payer(): BelongsTo
    {
        return $this->belongsTo(User::class, 'paid_by');
    }

    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    public function shares(): HasMany
    {
        return $this->hasMany(ExpenseShare::class, 'expense_id');
    }
}