<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Concerns\CreatesGroups;
use Tests\TestCase;

class GroupTest extends TestCase
{
    use CreatesGroups, RefreshDatabase;

    public function test_creating_a_group_makes_the_creator_its_owner(): void
    {
        $user = $this->signIn();

        $response = $this->postJson('/api/groups', ['name' => 'Trip Bali'])
            ->assertCreated()
            ->assertJsonPath('data.name', 'Trip Bali')
            ->assertJsonPath('data.my_role', 'owner')
            ->assertJsonPath('data.member_count', 1);

        $this->assertMatchesRegularExpression('/^[A-HJ-NP-Z2-9]{8}$/', $response->json('data.invite_code'));
        $this->assertDatabaseHas('group_members', ['user_id' => $user->id, 'role' => 'owner']);
    }

    public function test_group_name_is_required(): void
    {
        $this->signIn();

        $this->postJson('/api/groups', ['name' => ''])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('name');
    }

    public function test_list_only_shows_groups_the_user_belongs_to(): void
    {
        $a = $this->makeUser();
        $b = $this->makeUser();
        $this->makeGroup($a, [], 'Punya A');
        $this->makeGroup($b, [], 'Punya B');

        $this->signIn($a);

        $this->getJson('/api/groups')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.name', 'Punya A')
            ->assertJsonPath('data.0.member_count', 1);
    }

    public function test_joining_with_an_invite_code_makes_the_user_a_member(): void
    {
        $owner = $this->makeUser();
        $member = $this->makeUser();
        $group = $this->makeGroup($owner);

        $this->signIn($member);

        // Kode diketik huruf kecil dan dengan spasi: tetap harus diterima.
        $this->postJson('/api/groups/join', ['invite_code' => ' '.strtolower($group->invite_code).' '])
            ->assertOk()
            ->assertJsonPath('data.my_role', 'member')
            ->assertJsonPath('data.member_count', 2);
    }

    public function test_joining_twice_is_rejected(): void
    {
        [, $b, $group] = $this->pair();

        $this->signIn($b);

        $this->postJson('/api/groups/join', ['invite_code' => $group->invite_code])
            ->assertStatus(409)
            ->assertJsonPath('message', 'Kamu sudah menjadi anggota grup ini.');
    }

    public function test_an_unknown_invite_code_is_rejected(): void
    {
        $this->signIn();

        $this->postJson('/api/groups/join', ['invite_code' => 'ZZZZZZZZ'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('invite_code');
    }

    public function test_a_full_group_does_not_accept_new_members(): void
    {
        $owner = $this->makeUser();
        $group = $this->makeGroup($owner, User::factory()->count(19)->create()->all());

        $this->signIn($this->makeUser());

        $this->postJson('/api/groups/join', ['invite_code' => $group->invite_code])
            ->assertUnprocessable()
            ->assertJsonPath('message', 'Grup sudah penuh (maksimal 20 anggota).');
    }

    public function test_non_members_cannot_see_or_touch_a_group(): void
    {
        $group = $this->makeGroup($this->makeUser());

        $this->signIn();
        $base = "/api/groups/{$group->id}";

        $this->getJson($base)->assertNotFound();
        $this->putJson($base, ['name' => 'Curian'])->assertNotFound();
        $this->deleteJson($base)->assertNotFound();
        $this->postJson("{$base}/leave")->assertNotFound();
        $this->getJson("{$base}/expenses")->assertNotFound();
        $this->getJson("{$base}/balances")->assertNotFound();
        $this->getJson("{$base}/history")->assertNotFound();
    }

    public function test_a_member_can_see_the_group_and_its_members(): void
    {
        [$a, $b, $group] = $this->pair();

        $this->signIn($b);

        $this->getJson("/api/groups/{$group->id}")
            ->assertOk()
            ->assertJsonPath('data.my_role', 'member')
            ->assertJsonPath('data.owner.id', $a->id)
            ->assertJsonCount(2, 'data.members');
    }

    public function test_only_the_owner_can_manage_the_group(): void
    {
        [$a, $b, $group] = $this->pair();
        $base = "/api/groups/{$group->id}";

        $this->signIn($b);
        $this->putJson($base, ['name' => 'Diubah'])->assertForbidden();
        $this->postJson("{$base}/regenerate-code")->assertForbidden();
        $this->deleteJson($base)->assertForbidden();
        $this->deleteJson("{$base}/members/{$a->id}")->assertForbidden();

        $this->signIn($a);
        $this->putJson($base, ['name' => 'Trip Bali 2026'])
            ->assertOk()
            ->assertJsonPath('data.name', 'Trip Bali 2026');
    }

    public function test_regenerating_the_code_invalidates_the_old_one(): void
    {
        [$a, , $group] = $this->pair();
        $oldCode = $group->invite_code;

        $this->signIn($a);
        $newCode = $this->postJson("/api/groups/{$group->id}/regenerate-code")
            ->assertOk()
            ->json('data.invite_code');

        $this->assertNotSame($oldCode, $newCode);
        $this->assertDatabaseHas('split_groups', ['id' => $group->id, 'invite_code' => $newCode]);

        $this->signIn();
        $this->postJson('/api/groups/join', ['invite_code' => $oldCode])->assertUnprocessable();
    }

    public function test_deleting_a_group_removes_its_memberships(): void
    {
        [$a, , $group] = $this->pair();

        $this->signIn($a);
        $this->deleteJson("/api/groups/{$group->id}")->assertOk();

        $this->assertDatabaseMissing('split_groups', ['id' => $group->id]);
        $this->assertDatabaseCount('group_members', 0);
    }

    public function test_a_member_can_leave_but_the_owner_cannot(): void
    {
        [$a, $b, $group] = $this->pair();
        $url = "/api/groups/{$group->id}/leave";

        $this->signIn($a);
        $this->postJson($url)->assertUnprocessable();

        $this->signIn($b);
        $this->postJson($url)->assertOk();

        $this->assertDatabaseMissing('group_members', ['group_id' => $group->id, 'user_id' => $b->id]);
    }

    public function test_owner_can_remove_a_member_but_not_themselves_or_strangers(): void
    {
        [$a, $b, $group] = $this->pair();
        $stranger = $this->makeUser();
        $base = "/api/groups/{$group->id}/members";

        $this->signIn($a);
        $this->deleteJson("{$base}/{$a->id}")->assertUnprocessable();
        $this->deleteJson("{$base}/{$stranger->id}")->assertNotFound();
        $this->deleteJson("{$base}/{$b->id}")->assertOk();

        $this->assertDatabaseMissing('group_members', ['group_id' => $group->id, 'user_id' => $b->id]);
    }
}