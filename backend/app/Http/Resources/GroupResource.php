<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class GroupResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'invite_code' => $this->invite_code,
            'my_role' => $this->pivot?->role,
            'owner' => $this->whenLoaded('owner', fn () => $this->owner->only(['id', 'name'])),
            'member_count' => $this->whenCounted('members'),
            'members' => $this->whenLoaded('members', fn () => $this->members->map(fn ($member) => [
                'id' => $member->id,
                'name' => $member->name,
                'role' => $member->pivot->role,
                'joined_at' => $member->pivot->joined_at,
            ])->values()),
            'created_at' => $this->created_at,
        ];
    }
}