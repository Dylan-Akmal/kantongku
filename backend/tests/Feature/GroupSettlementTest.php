<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Concerns\CreatesGroups;
use Tests\TestCase;

class GroupSettlementTest extends TestCase
{
    use CreatesGroups, RefreshDatabase;

    public function test_balances_follow_expenses_in_every_split_mode(): void
    {
        [$a, $b, $group] = $this->pair();
        $this->signIn($a);

        $this->postExpense($group, $this->equalPayload($a->id, 300000, [$a->id, $b->id], ['title' => 'Makan malam']))
            ->assertCreated();
        $this->postExpense($group, $this->equalPayload($a->id, 100001, [$a->id, $b->id], ['title' => 'Parkir']))
            ->assertCreated();
        $this->postExpense($group, [
            'title' => 'Taksi',
            'total_amount' => 90000,
            'paid_by' => $b->id,
            'expense_date' => '2026-10-20',
            'split_type' => 'exact',
            'participants' => [
                ['user_id' => $a->id, 'amount' => 60000],
                ['user_id' => $b->id, 'amount' => 30000],
            ],
        ])->assertCreated();
        $this->postExpense($group, [
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

        $url = "/api/groups/{$group->id}/balances";

        $response = $this->getJson($url)
            ->assertOk()
            ->assertJsonPath('data.my_balance', 290000)
            ->assertJsonCount(1, 'data.settle_up')
            ->assertJsonPath('data.settle_up.0.from.id', $b->id)
            ->assertJsonPath('data.settle_up.0.to.id', $a->id)
            ->assertJsonPath('data.settle_up.0.amount', 290000);

        $balances = collect($response->json('data.balances'))->pluck('balance', 'user_id');

        $this->assertSame(290000, $balances[$a->id]);
        $this->assertSame(-290000, $balances[$b->id]);

        $this->signIn($b);
        $this->getJson($url)->assertJsonPath('data.my_balance', -290000);
    }

    public function test_three_people_settle_up_with_two_payments(): void
    {
        [$a, $b, $c, $group] = $this->trio();
        $this->signIn($a);

        $this->postExpense($group, $this->equalPayload($a->id, 300000, [$a->id, $b->id, $c->id]))
            ->assertCreated();

        $response = $this->getJson("/api/groups/{$group->id}/balances")
            ->assertOk()
            ->assertJsonPath('data.my_balance', 200000)
            ->assertJsonCount(2, 'data.settle_up');

        $payments = collect($response->json('data.settle_up'));

        $this->assertEqualsCanonicalizing([$b->id, $c->id], $payments->pluck('from.id')->all());
        $this->assertSame([$a->id, $a->id], $payments->pluck('to.id')->all());
        $this->assertSame([100000, 100000], $payments->pluck('amount')->all());
    }

    public function test_deleted_expenses_are_not_counted_in_balances(): void
    {
        [$a, $b, $group] = $this->pair();
        $this->signIn($a);

        $id = $this->postExpense($group, $this->equalPayload($a->id, 300000, [$a->id, $b->id]))
            ->assertCreated()
            ->json('data.id');

        $this->deleteJson("/api/groups/{$group->id}/expenses/{$id}")->assertOk();

        $this->getJson("/api/groups/{$group->id}/balances")
            ->assertJsonPath('data.my_balance', 0)
            ->assertJsonCount(0, 'data.settle_up');
    }

    public function test_settlements_reduce_the_debt_until_everything_is_balanced(): void
    {
        [$a, $b, $group] = $this->pair();
        $this->signIn($a);
        $this->postExpense($group, $this->equalPayload($a->id, 280000, [$a->id, $b->id]))->assertCreated();

        $this->signIn($b);
        $url = "/api/groups/{$group->id}/settlements";

        $this->postJson($url, ['to_user_id' => $a->id, 'amount' => 40000, 'note' => 'Cicil pertama'])
            ->assertCreated()
            ->assertJsonPath('data.from.id', $b->id)
            ->assertJsonPath('data.to.id', $a->id)
            ->assertJsonPath('data.amount', 40000)
            ->assertJsonPath('meta.my_balance', -100000);

        $this->getJson("/api/groups/{$group->id}/balances")
            ->assertJsonPath('data.my_balance', -100000)
            ->assertJsonPath('data.settle_up.0.amount', 100000);

        $this->postJson($url, ['to_user_id' => $a->id, 'amount' => 100000, 'note' => 'Lunas'])
            ->assertCreated()
            ->assertJsonPath('meta.my_balance', 0);

        $this->getJson("/api/groups/{$group->id}/balances")
            ->assertJsonPath('data.my_balance', 0)
            ->assertJsonCount(0, 'data.settle_up');
    }

    public function test_invalid_settlements_are_rejected(): void
    {
        [$a, $b, $group] = $this->pair();
        $stranger = $this->makeUser();
        $this->signIn($a);
        $this->postExpense($group, $this->equalPayload($a->id, 280000, [$a->id, $b->id]))->assertCreated();

        $url = "/api/groups/{$group->id}/settlements";

        $this->signIn($b);
        $this->postJson($url, ['to_user_id' => $a->id, 'amount' => 200000])
            ->assertUnprocessable()
            ->assertJsonPath('errors.amount.0', 'Nominal melebihi utangmu (140000).');
        $this->postJson($url, ['to_user_id' => $b->id, 'amount' => 1000])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('to_user_id');
        $this->postJson($url, ['to_user_id' => $stranger->id, 'amount' => 1000])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('to_user_id');
        $this->postJson($url, ['to_user_id' => $a->id, 'amount' => 0])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('amount');

        $this->signIn($a);
        $this->postJson($url, ['to_user_id' => $b->id, 'amount' => 1000])
            ->assertUnprocessable()
            ->assertJsonPath('errors.amount.0', 'Kamu tidak punya utang di grup ini.');

        $this->signIn($stranger);
        $this->postJson($url, ['to_user_id' => $a->id, 'amount' => 1000])->assertNotFound();

        $this->assertDatabaseCount('settlements', 0);
    }

    public function test_a_debtor_cannot_pay_someone_who_is_not_owed(): void
    {
        [$a, $b, $c, $group] = $this->trio();
        $this->signIn($a);
        $this->postExpense($group, $this->equalPayload($a->id, 300000, [$a->id, $b->id, $c->id]))
            ->assertCreated();

        $this->signIn($b);

        $this->postJson("/api/groups/{$group->id}/settlements", ['to_user_id' => $c->id, 'amount' => 10000])
            ->assertUnprocessable()
            ->assertJsonPath('errors.amount.0', 'Anggota tujuan tidak sedang menunggu pembayaran.');
    }

    public function test_a_payment_cannot_exceed_what_the_recipient_is_owed(): void
    {
        [$a, $b, $c, $group] = $this->trio();
        $this->signIn($a);

        // A: +30000, B: -100000, C: +70000
        $this->postExpense($group, [
            'title' => 'Belanja A',
            'total_amount' => 100000,
            'paid_by' => $a->id,
            'expense_date' => '2026-10-20',
            'split_type' => 'exact',
            'participants' => [
                ['user_id' => $a->id, 'amount' => 70000],
                ['user_id' => $b->id, 'amount' => 30000],
            ],
        ])->assertCreated();
        $this->postExpense($group, [
            'title' => 'Belanja C',
            'total_amount' => 140000,
            'paid_by' => $c->id,
            'expense_date' => '2026-10-20',
            'split_type' => 'exact',
            'participants' => [
                ['user_id' => $c->id, 'amount' => 70000],
                ['user_id' => $b->id, 'amount' => 70000],
            ],
        ])->assertCreated();

        $url = "/api/groups/{$group->id}/settlements";

        $this->signIn($b);
        $this->postJson($url, ['to_user_id' => $a->id, 'amount' => 40000])
            ->assertUnprocessable()
            ->assertJsonPath('errors.amount.0', 'Nominal melebihi yang harus diterima penerima (30000).');

        $this->postJson($url, ['to_user_id' => $a->id, 'amount' => 30000])->assertCreated();
        $this->postJson($url, ['to_user_id' => $c->id, 'amount' => 70000])
            ->assertCreated()
            ->assertJsonPath('meta.my_balance', 0);
    }

    public function test_only_the_payer_or_the_owner_can_delete_a_settlement(): void
    {
        [$a, $b, $c, $group] = $this->trio();
        $this->signIn($a);
        $this->postExpense($group, $this->equalPayload($a->id, 300000, [$a->id, $b->id, $c->id]))
            ->assertCreated();

        $url = "/api/groups/{$group->id}/settlements";
        $payment = ['to_user_id' => $a->id, 'amount' => 10000];

        $this->signIn($b);
        $first = $this->postJson($url, $payment)->assertCreated()->json('data.id');

        $this->signIn($c);
        $this->deleteJson("{$url}/{$first}")->assertForbidden();

        $this->signIn($b);
        $this->deleteJson("{$url}/{$first}")->assertOk();

        $second = $this->postJson($url, $payment)->assertCreated()->json('data.id');

        $this->signIn($a);
        $this->deleteJson("{$url}/{$second}")->assertOk();

        $this->assertDatabaseCount('settlements', 0);

        $this->signIn($b);
        $this->getJson("/api/groups/{$group->id}/balances")->assertJsonPath('data.my_balance', -100000);
    }

    public function test_a_member_cannot_leave_until_their_balance_is_zero(): void
    {
        [$a, $b, $group] = $this->pair();
        $this->signIn($a);
        $this->postExpense($group, $this->equalPayload($a->id, 280000, [$a->id, $b->id]))->assertCreated();

        $this->signIn($b);
        $leave = "/api/groups/{$group->id}/leave";

        $this->postJson($leave)
            ->assertStatus(409)
            ->assertJsonPath('message', 'Saldomu di grup ini belum nol. Lunasi dulu sebelum keluar.');

        $this->postJson("/api/groups/{$group->id}/settlements", ['to_user_id' => $a->id, 'amount' => 140000])
            ->assertCreated()
            ->assertJsonPath('meta.my_balance', 0);

        $this->postJson($leave)->assertOk();
        $this->assertDatabaseMissing('group_members', ['group_id' => $group->id, 'user_id' => $b->id]);
    }

    public function test_the_owner_cannot_remove_a_member_who_still_owes_money(): void
    {
        [$a, $b, $group] = $this->pair();
        $this->signIn($a);
        $this->postExpense($group, $this->equalPayload($a->id, 280000, [$a->id, $b->id]))->assertCreated();

        $remove = "/api/groups/{$group->id}/members/{$b->id}";

        $this->deleteJson($remove)->assertStatus(409);

        $this->signIn($b);
        $this->postJson("/api/groups/{$group->id}/settlements", ['to_user_id' => $a->id, 'amount' => 140000])
            ->assertCreated();

        $this->signIn($a);
        $this->deleteJson($remove)->assertOk();
        $this->assertDatabaseMissing('group_members', ['group_id' => $group->id, 'user_id' => $b->id]);
    }

    public function test_history_lists_expenses_and_settlements_newest_first(): void
    {
        [$a, $b, $group] = $this->pair();
        $ids = [$a->id, $b->id];

        $this->signIn($a);
        $this->postExpense($group, $this->equalPayload($a->id, 280000, $ids, ['title' => 'Makan malam']))
            ->assertCreated();

        $this->travel(10)->seconds();
        $this->postExpense($group, $this->equalPayload($a->id, 100000, $ids, ['title' => 'Parkir']))
            ->assertCreated();

        $this->travel(10)->seconds();
        $this->signIn($b);
        $this->postJson("/api/groups/{$group->id}/settlements", [
            'to_user_id' => $a->id,
            'amount' => 40000,
            'note' => 'Cicil',
        ])->assertCreated();

        $url = "/api/groups/{$group->id}/history";

        $this->getJson($url)
            ->assertOk()
            ->assertJsonCount(3, 'data')
            ->assertJsonPath('data.0.type', 'settlement')
            ->assertJsonPath('data.0.amount', 40000)
            ->assertJsonPath('data.1.type', 'expense')
            ->assertJsonPath('data.1.title', 'Parkir')
            ->assertJsonPath('data.2.title', 'Makan malam')
            ->assertJsonPath('meta.total', 3);

        $this->getJson("{$url}?per_page=2")
            ->assertJsonCount(2, 'data')
            ->assertJsonPath('meta.last_page', 2);

        $this->getJson("{$url}?per_page=2&page=2")->assertJsonCount(1, 'data');
    }
}