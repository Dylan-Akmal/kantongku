<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;

class SplitGroup extends Model
{
    protected $fillable = [
        'owner_id',
        'name',
        'invite_code',
    ];

    public function owner(): BelongsTo
    {
        return $this->belongsTo(User::class, 'owner_id');
    }

    public function members(): BelongsToMany
    {
        return $this->belongsToMany(User::class, 'group_members', 'group_id', 'user_id')
            ->withPivot('role', 'joined_at');
    }

    public function memberships(): HasMany
    {
        return $this->hasMany(GroupMember::class, 'group_id');
    }

    public function expenses(): HasMany
    {
        return $this->hasMany(GroupExpense::class, 'group_id');
    }

    public function settlements(): HasMany
    {
        return $this->hasMany(Settlement::class, 'group_id');
    }
}