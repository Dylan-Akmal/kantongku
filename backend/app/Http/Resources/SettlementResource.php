<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class SettlementResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'group_id' => $this->group_id,
            'from' => $this->whenLoaded('fromUser', fn () => $this->fromUser->only(['id', 'name'])),
            'to' => $this->whenLoaded('toUser', fn () => $this->toUser->only(['id', 'name'])),
            'amount' => $this->amount,
            'note' => $this->note,
            'settled_at' => $this->settled_at,
        ];
    }
}