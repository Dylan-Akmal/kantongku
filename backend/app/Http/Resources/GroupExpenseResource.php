<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class GroupExpenseResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'group_id' => $this->group_id,
            'title' => $this->title,
            'total_amount' => $this->total_amount,
            'split_type' => $this->split_type,
            'expense_date' => $this->expense_date->format('Y-m-d'),
            'note' => $this->note,
            'paid_by' => $this->whenLoaded('payer', fn () => $this->payer->only(['id', 'name'])),
            'created_by' => $this->whenLoaded('creator', fn () => $this->creator->only(['id', 'name'])),
            'shares' => $this->whenLoaded('shares', fn () => $this->shares->map(fn ($share) => [
                'user' => $share->user?->only(['id', 'name']),
                'amount_owed' => $share->amount_owed,
            ])->values()),
            'created_at' => $this->created_at,
        ];
    }
}