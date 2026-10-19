<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class WalletResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'type' => $this->type,
            'initial_balance' => $this->initial_balance,
            'balance' => $this->balance,
            'is_archived' => $this->is_archived,
            'created_at' => $this->created_at,
        ];
    }
}