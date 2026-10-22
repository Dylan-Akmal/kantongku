<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Concerns\CreatesGroups;
use Tests\TestCase;

class GroupExpenseTest extends TestCase
{
    use CreatesGroups, RefreshDatabase;

    public function test_equal_split_creates_one_share_per_participant(): void
    {
        [$a, $b, $group] = $this->pair();
        $this->signIn($a);

        $response = $this->postExpense($group, $this->equalPayload($a->id, 300000, [$a->id, $b->id]))
            ->assertCreated()
            ->assertJsonPath('data.total_amount', 300000)
            ->assertJsonPath('data.paid_by.id', $a->id)
            ->assertJsonPath('data.created_by.id', $a->id)
            ->assertJsonCount(2, 'data.shares');

        $shares = collect($response->json('data.shares'))->pluck('amount_owed', 'user.id');

        $this->assertSame(150000, $shares[$a->id]);
        $this->assertSame(150000, $shares[$b->id]);
    }

    public function test_equal_split_charges_the_rounding_remainder_to_the_payer(): void
    {
        [$a, $b, $group] = $this->pair();
        $this->signIn($a);

        $response = $this->postExpense($group, $this->equalPayload($a->id, 100001, [$a->id, $b->id]))
            ->assertCreated();

        $shares = collect($response->json('data.shares'))->pluck('amount_owed', 'user.id');

        $this->assertSame(50001, $shares[$a->id]);
        $this->assertSame(50000, $shares[$b->id]);
    }

    public function test_exact_split_uses_the_given_amounts(): void
    {
        [$a, $b, $group] = $this->pair();
        $this->signIn($a);

        $response = $this->postExpense($group, [
            'title' => 'Taksi',
            'total_amount' => 90000,
            'paid_by' => $b->id,
            'expense_date' => '2026-10-20',
            'split_type' => 'exact',
            'participants' => [
                ['user_id' => $a->id, 'amount' => 60000],
                ['user_id' => $b->id, 'amount' => 30000],
            ],
        ])->assertCreated()->assertJsonPath('data.paid_by.id', $b->id);

        $shares = collect($response->json('data.shares'))->pluck('amount_owed', 'user.id');

        $this->assertSame(60000, $shares[$a->id]);
        $this->assertSame(30000, $shares[$b->id]);
    }

    public function test_percent_split_divides_by_percentage(): void
    {
        [$a, $b, $group] = $this->pair();
        $this->signIn($a);

        $response = $this->postExpense($group, [
            'title' => 'Tiket wisata',
            'total_amount' => 200000,
            'paid_by' => $a->id,
            'expense_date' => '2026-10-20',
            'split_type' => 'percent',
            'participants' => [
                ['user_id' => $a->id, 'percent' => 25],
                ['user_id' => $b->id, 'percent' => 75],
            ],
        ])->assertCreated();

        $shares = collect($response->json('data.shares'))->pluck('amount_owed', 'user.id');

        $this->assertSame(50000, $shares[$a->id]);
        $this->assertSame(150000, $shares[$b->id]);
    }

    public function test_the_payer_does_not_have_to_be_a_participant(): void
    {
        [$a, $b, $c, $group] = $this->trio();
        $this->signIn($a);

        $this->postExpense($group, $this->equalPayload($a->id, 90000, [$b->id, $c->id]))
            ->assertCreated();

        $this->assertDatabaseMissing('expense_shares', ['user_id' => $a->id]);
        $this->assertDatabaseHas('expense_shares', ['user_id' => $b->id, 'amount_owed' => 45000]);
        $this->assertDatabaseHas('expense_shares', ['user_id' => $c->id, 'amount_owed' => 45000]);

        $this->getJson("/api/groups/{$group->id}/balances")->assertJsonPath('data.my_balance', 90000);
    }

    public function test_invalid_expenses_are_rejected(): void
    {
        [$a, $b, $group] = $this->pair();
        $stranger = $this->makeUser();
        $this->signIn($a);

        $base = $this->equalPayload($a->id, 100000, [$a->id, $b->id]);

        $cases = [
            ['participants', [
                'split_type' => 'exact',
                'participants' => [
                    ['user_id' => $a->id, 'amount' => 60000],
                    ['user_id' => $b->id, 'amount' => 30000],
                ],
            ]],
            ['participants', [
                'split_type' => 'percent',
                'participants' => [
                    ['user_id' => $a->id, 'percent' => 25],
                    ['user_id' => $b->id, 'percent' => 70],
                ],
            ]],
            ['paid_by', ['paid_by' => $stranger->id]],
            ['participants.1.user_id', ['participants' => [['user_id' => $a->id], ['user_id' => $stranger->id]]]],
            ['participants', ['participants' => []]],
            ['expense_date', ['expense_date' => '20-10-2026']],
            ['title', ['title' => '']],
            ['total_amount', ['total_amount' => 0]],
        ];

        foreach ($cases as [$field, $override]) {
            $this->postExpense($group, array_merge($base, $override))
                ->assertUnprocessable()
                ->assertJsonValidationErrors($field);
        }

        $this->postExpense($group, array_merge($base, [
            'participants' => [['user_id' => $a->id], ['user_id' => $a->id]],
        ]))->assertUnprocessable();

        $this->assertDatabaseCount('group_expenses', 0);
    }

    public function test_non_members_cannot_use_a_groups_expenses(): void
    {
        [$a, $b, $group] = $this->pair();
        $this->signIn($a);
        $id = $this->postExpense($group, $this->equalPayload($a->id, 1000, [$a->id, $b->id]))
            ->assertCreated()
            ->json('data.id');

        $this->signIn();

        $this->postExpense($group, $this->equalPayload($a->id, 1000, [$a->id, $b->id]))->assertNotFound();
        $this->getJson("/api/groups/{$group->id}/expenses")->assertNotFound();
        $this->getJson("/api/groups/{$group->id}/expenses/{$id}")->assertNotFound();
    }

    public function test_only_the_creator_or_the_payer_can_update_an_expense(): void
    {
        [$a, $b, $c, $group] = $this->trio();
        $this->signIn($a);

        $id = $this->postExpense($group, $this->equalPayload($b->id, 90000, [$a->id, $b->id, $c->id]))
            ->assertCreated()
            ->json('data.id');

        $url = "/api/groups/{$group->id}/expenses/{$id}";
        $payload = $this->equalPayload($b->id, 90000, [$a->id, $b->id, $c->id], ['title' => 'Diubah']);

        $this->signIn($c);
        $this->putJson($url, $payload)->assertForbidden();

        $this->signIn($b);
        $this->putJson($url, $payload)->assertOk()->assertJsonPath('data.title', 'Diubah');

        $this->signIn($a);
        $this->putJson($url, array_merge($payload, ['title' => 'Diubah lagi']))->assertOk();
    }

    public function test_updating_an_expense_replaces_its_shares(): void
    {
        [$a, $b, $group] = $this->pair();
        $this->signIn($a);

        $id = $this->postExpense($group, $this->equalPayload($a->id, 300000, [$a->id, $b->id]))
            ->assertCreated()
            ->json('data.id');

        $this->putJson("/api/groups/{$group->id}/expenses/{$id}", [
            'title' => 'Makan malam',
            'total_amount' => 400000,
            'paid_by' => $a->id,
            'expense_date' => '2026-10-20',
            'split_type' => 'exact',
            'participants' => [
                ['user_id' => $a->id, 'amount' => 250000],
                ['user_id' => $b->id, 'amount' => 150000],
            ],
        ])->assertOk()->assertJsonPath('data.total_amount', 400000);

        $this->assertDatabaseCount('expense_shares', 2);
        $this->assertDatabaseHas('expense_shares', ['expense_id' => $id, 'user_id' => $a->id, 'amount_owed' => 250000]);
        $this->assertDatabaseHas('expense_shares', ['expense_id' => $id, 'user_id' => $b->id, 'amount_owed' => 150000]);
    }

    public function test_the_creator_payer_or_owner_can_delete_an_expense(): void
    {
        [$a, $b, $c, $group] = $this->trio();
        $everyone = [$a->id, $b->id, $c->id];

        $this->signIn($b);
        $first = $this->postExpense($group, $this->equalPayload($b->id, 90000, $everyone))
            ->assertCreated()
            ->json('data.id');

        $this->signIn($c);
        $this->deleteJson("/api/groups/{$group->id}/expenses/{$first}")->assertForbidden();

        $this->signIn($a);
        $this->deleteJson("/api/groups/{$group->id}/expenses/{$first}")->assertOk();

        $this->signIn($b);
        $second = $this->postExpense($group, $this->equalPayload($b->id, 90000, $everyone))
            ->assertCreated()
            ->json('data.id');

        $this->deleteJson("/api/groups/{$group->id}/expenses/{$second}")->assertOk();
    }

    public function test_deleting_an_expense_is_a_soft_delete_that_removes_it_from_everything(): void
    {
        [$a, $b, $group] = $this->pair();
        $this->signIn($a);

        $id = $this->postExpense($group, $this->equalPayload($a->id, 300000, [$a->id, $b->id]))
            ->assertCreated()
            ->json('data.id');

        $this->deleteJson("/api/groups/{$group->id}/expenses/{$id}")->assertOk();

        $this->assertSoftDeleted('group_expenses', ['id' => $id]);
        $this->getJson("/api/groups/{$group->id}/expenses")->assertJsonCount(0, 'data');
        $this->getJson("/api/groups/{$group->id}/expenses/{$id}")->assertNotFound();
        $this->getJson("/api/groups/{$group->id}/balances")->assertJsonPath('data.my_balance', 0);
    }

    public function test_list_is_ordered_by_date_newest_first_and_paginated(): void
    {
        [$a, $b, $group] = $this->pair();
        $this->signIn($a);
        $ids = [$a->id, $b->id];

        foreach (['2026-10-18', '2026-10-20', '2026-10-19'] as $date) {
            $this->postExpense($group, $this->equalPayload($a->id, 1000, $ids, [
                'title' => "Hari {$date}",
                'expense_date' => $date,
            ]))->assertCreated();
        }

        $this->getJson("/api/groups/{$group->id}/expenses")
            ->assertOk()
            ->assertJsonPath('data.0.title', 'Hari 2026-10-20')
            ->assertJsonPath('data.1.title', 'Hari 2026-10-19')
            ->assertJsonPath('data.2.title', 'Hari 2026-10-18');

        $this->getJson("/api/groups/{$group->id}/expenses?per_page=2")
            ->assertJsonCount(2, 'data')
            ->assertJsonPath('meta.last_page', 2);
    }
}