<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Casts\Attribute;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Wallet extends Model
{
    protected $fillable = [
        'user_id',
        'name',
        'type',
        'initial_balance',
        'is_archived',
    ];

    protected function casts(): array
    {
        return [
            'initial_balance' => 'integer',
            'is_archived' => 'boolean',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function transactions(): HasMany
    {
        return $this->hasMany(Transaction::class);
    }

    public function incomingTransfers(): HasMany
    {
        return $this->hasMany(Transaction::class, 'to_wallet_id');
    }

    /**
     * Menambahkan hasil penjumlahan transaksi agar saldo bisa dihitung.
     * Harus dipakai sebelum membaca atribut $wallet->balance.
     */
    public function scopeWithBalance(Builder $query): Builder
    {
        return $query
            ->withSum(['transactions as income_sum' => fn ($q) => $q->where('type', 'income')], 'amount')
            ->withSum(['transactions as expense_sum' => fn ($q) => $q->where('type', 'expense')], 'amount')
            ->withSum(['transactions as transfer_out_sum' => fn ($q) => $q->where('type', 'transfer')], 'amount')
            ->withSum('incomingTransfers as transfer_in_sum', 'amount');
    }

    protected function balance(): Attribute
    {
        return Attribute::get(fn () => (int) $this->initial_balance
            + (int) ($this->income_sum ?? 0)
            - (int) ($this->expense_sum ?? 0)
            - (int) ($this->transfer_out_sum ?? 0)
            + (int) ($this->transfer_in_sum ?? 0));
    }
}