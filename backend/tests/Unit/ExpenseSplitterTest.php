<?php

namespace Tests\Unit;

use App\Services\ExpenseSplitter;
use Illuminate\Validation\ValidationException;
use Tests\TestCase;

class ExpenseSplitterTest extends TestCase
{
    private ExpenseSplitter $splitter;

    protected function setUp(): void
    {
        parent::setUp();

        $this->splitter = new ExpenseSplitter();
    }

    public function test_equal_split_gives_remainder_to_payer(): void
    {
        $shares = $this->splitter->split('equal', 100001, 1, $this->ids([1, 2]));

        $this->assertSame([1 => 50001, 2 => 50000], $shares);
    }

    public function test_equal_split_gives_remainder_to_first_participant_when_payer_is_not_a_participant(): void
    {
        $shares = $this->splitter->split('equal', 100, 9, $this->ids([1, 2, 3]));

        $this->assertSame([1 => 34, 2 => 33, 3 => 33], $shares);
    }

    public function test_equal_split_three_ways_charges_remainder_to_payer(): void
    {
        $shares = $this->splitter->split('equal', 100000, 2, $this->ids([1, 2, 3]));

        $this->assertSame([1 => 33333, 2 => 33334, 3 => 33333], $shares);
    }

    public function test_equal_split_always_sums_to_the_total(): void
    {
        foreach ([1, 7, 99, 100001, 999999999999] as $total) {
            foreach (range(1, 7) as $count) {
                $ids = range(1, $count);
                $shares = $this->splitter->split('equal', $total, $ids[0], $this->ids($ids));

                $this->assertSame($total, array_sum($shares), "total $total dibagi $count orang");
            }
        }
    }

    public function test_exact_split_returns_the_given_amounts(): void
    {
        $shares = $this->splitter->split('exact', 90000, 2, [
            ['user_id' => 1, 'amount' => 60000],
            ['user_id' => 2, 'amount' => 30000],
        ]);

        $this->assertSame([1 => 60000, 2 => 30000], $shares);
    }

    public function test_exact_split_rejects_a_sum_that_differs_from_the_total(): void
    {
        $this->expectException(ValidationException::class);

        $this->splitter->split('exact', 100000, 2, [
            ['user_id' => 1, 'amount' => 60000],
            ['user_id' => 2, 'amount' => 30000],
        ]);
    }

    public function test_percent_split_charges_rounding_remainder_to_payer(): void
    {
        $shares = $this->splitter->split('percent', 100, 2, [
            ['user_id' => 1, 'percent' => 33.33],
            ['user_id' => 2, 'percent' => 33.33],
            ['user_id' => 3, 'percent' => 33.34],
        ]);

        $this->assertSame([1 => 33, 2 => 34, 3 => 33], $shares);
    }

    public function test_percent_split_rejects_percentages_that_do_not_total_100(): void
    {
        $this->expectException(ValidationException::class);

        $this->splitter->split('percent', 200000, 1, [
            ['user_id' => 1, 'percent' => 25],
            ['user_id' => 2, 'percent' => 70],
        ]);
    }

    public function test_percent_split_divides_by_the_given_percentages(): void
    {
        $shares = $this->splitter->split('percent', 200000, 1, [
            ['user_id' => 1, 'percent' => 25],
            ['user_id' => 2, 'percent' => 75],
        ]);

        $this->assertSame([1 => 50000, 2 => 150000], $shares);
    }

    public function test_unknown_split_type_is_rejected(): void
    {
        $this->expectException(ValidationException::class);

        $this->splitter->split('weird', 1000, 1, $this->ids([1, 2]));
    }

    private function ids(array $ids): array
    {
        return array_map(fn (int $id) => ['user_id' => $id], $ids);
    }
}