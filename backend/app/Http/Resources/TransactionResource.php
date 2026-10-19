<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class TransactionResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'type' => $this->type,
            'amount' => $this->amount,
            'transaction_date' => $this->transaction_date->format('Y-m-d'),
            'note' => $this->note,
            'wallet' => $this->whenLoaded('wallet', fn () => $this->wallet->only(['id', 'name', 'type'])),
            'to_wallet' => $this->whenLoaded('toWallet', fn () => $this->toWallet?->only(['id', 'name', 'type'])),
            'category' => $this->whenLoaded('category', fn () => $this->category?->only(['id', 'name', 'type'])),
            'created_at' => $this->created_at,
        ];
    }
}