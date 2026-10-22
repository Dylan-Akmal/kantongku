<?php

namespace Tests\Concerns;

use App\Models\SplitGroup;
use App\Models\User;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;

trait CreatesGroups
{
    /** Membuat grup langsung di database: $owner jadi pemilik, $members jadi anggota biasa. */
    protected function makeGroup(User $owner, array $members = [], string $name = 'Trip Bali'): SplitGroup
    {
        $group = SplitGroup::create([
            'owner_id' => $owner->id,
            'name' => $name,
            'invite_code' => strtoupper(Str::random(8)),
        ]);

        $group->memberships()->create(['user_id' => $owner->id, 'role' => 'owner']);

        foreach ($members as $member) {
            $group->memberships()->create(['user_id' => $member->id, 'role' => 'member']);
        }

        return $group;
    }

    /** @return array{0: User, 1: User, 2: SplitGroup} pemilik, satu anggota, grupnya */
    protected function pair(): array
    {
        $a = $this->makeUser();
        $b = $this->makeUser();

        return [$a, $b, $this->makeGroup($a, [$b])];
    }

    /** @return array{0: User, 1: User, 2: User, 3: SplitGroup} pemilik, dua anggota, grupnya */
    protected function trio(): array
    {
        $a = $this->makeUser();
        $b = $this->makeUser();
        $c = $this->makeUser();

        return [$a, $b, $c, $this->makeGroup($a, [$b, $c])];
    }

    protected function equalPayload(int $paidBy, int $total, array $userIds, array $override = []): array
    {
        return array_merge([
            'title' => 'Makan malam',
            'total_amount' => $total,
            'paid_by' => $paidBy,
            'expense_date' => '2026-10-20',
            'split_type' => 'equal',
            'participants' => array_map(fn (int $id) => ['user_id' => $id], $userIds),
        ], $override);
    }

    protected function postExpense(SplitGroup $group, array $payload): TestResponse
    {
        return $this->postJson("/api/groups/{$group->id}/expenses", $payload);
    }
}