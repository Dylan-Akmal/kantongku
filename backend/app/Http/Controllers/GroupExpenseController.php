<?php

namespace App\Http\Controllers;

use App\Http\Resources\GroupExpenseResource;
use App\Models\GroupExpense;
use App\Models\SplitGroup;
use App\Services\ExpenseSplitter;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

class GroupExpenseController extends Controller
{
    private const RELATIONS = ['payer:id,name', 'creator:id,name', 'shares.user:id,name'];

    public function index(Request $request, string $id): AnonymousResourceCollection
    {
        $group = $this->groupFor($request, $id);

        $request->validate([
            'per_page' => ['nullable', 'integer', 'min:1', 'max:100'],
        ]);

        $expenses = $group->expenses()
            ->with(self::RELATIONS)
            ->orderByDesc('expense_date')
            ->orderByDesc('id')
            ->paginate($request->integer('per_page', 15))
            ->withQueryString();

        return GroupExpenseResource::collection($expenses);
    }

    public function store(Request $request, string $id, ExpenseSplitter $splitter): JsonResponse
    {
        $group = $this->groupFor($request, $id);
        $data = $this->validated($request, $group);

        $shares = $splitter->split(
            $data['split_type'],
            (int) $data['total_amount'],
            (int) $data['paid_by'],
            $data['participants'],
        );

        $expense = DB::transaction(function () use ($request, $group, $data, $shares) {
            $expense = $group->expenses()->create([
                'paid_by' => $data['paid_by'],
                'created_by' => $request->user()->id,
                'title' => $data['title'],
                'total_amount' => $data['total_amount'],
                'split_type' => $data['split_type'],
                'expense_date' => $data['expense_date'],
                'note' => $data['note'] ?? null,
            ]);

            $this->saveShares($expense, $shares);

            return $expense;
        });

        return (new GroupExpenseResource($expense->load(self::RELATIONS)))
            ->additional(['message' => 'Pengeluaran bersama berhasil dicatat.'])
            ->response()
            ->setStatusCode(201);
    }

    public function show(Request $request, string $id, string $expenseId): GroupExpenseResource
    {
        $group = $this->groupFor($request, $id);

        return new GroupExpenseResource(
            $group->expenses()->with(self::RELATIONS)->findOrFail($expenseId)
        );
    }

    public function update(Request $request, string $id, string $expenseId, ExpenseSplitter $splitter): GroupExpenseResource
    {
        $group = $this->groupFor($request, $id);
        $expense = $group->expenses()->findOrFail($expenseId);

        $userId = $request->user()->id;
        abort_unless(
            $userId === $expense->created_by || $userId === $expense->paid_by,
            403,
            'Hanya pembuat atau pembayar pengeluaran yang boleh mengubahnya.'
        );

        $data = $this->validated($request, $group);

        $shares = $splitter->split(
            $data['split_type'],
            (int) $data['total_amount'],
            (int) $data['paid_by'],
            $data['participants'],
        );

        DB::transaction(function () use ($expense, $data, $shares) {
            $expense->update([
                'paid_by' => $data['paid_by'],
                'title' => $data['title'],
                'total_amount' => $data['total_amount'],
                'split_type' => $data['split_type'],
                'expense_date' => $data['expense_date'],
                'note' => $data['note'] ?? null,
            ]);

            $expense->shares()->delete();
            $this->saveShares($expense, $shares);
        });

        return (new GroupExpenseResource($expense->load(self::RELATIONS)))
            ->additional(['message' => 'Pengeluaran bersama berhasil diperbarui.']);
    }

    public function destroy(Request $request, string $id, string $expenseId): JsonResponse
    {
        $group = $this->groupFor($request, $id);
        $expense = $group->expenses()->findOrFail($expenseId);

        $userId = $request->user()->id;
        $isOwner = $group->pivot?->role === 'owner';

        abort_unless(
            $isOwner || $userId === $expense->created_by || $userId === $expense->paid_by,
            403,
            'Hanya pembuat, pembayar, atau pemilik grup yang boleh menghapus pengeluaran ini.'
        );

        $expense->delete();

        return response()->json([
            'message' => 'Pengeluaran bersama berhasil dihapus.',
        ]);
    }

    private function groupFor(Request $request, string $id): SplitGroup
    {
        return $request->user()->groups()
            ->where('split_groups.id', $id)
            ->firstOrFail();
    }

    private function validated(Request $request, SplitGroup $group): array
    {
        $memberIds = $group->memberships()->pluck('user_id')->all();
        $type = $request->input('split_type');

        return $request->validate([
            'title' => ['required', 'string', 'max:100'],
            'total_amount' => ['required', 'integer', 'min:1', 'max:999999999999'],
            'paid_by' => ['required', 'integer', Rule::in($memberIds)],
            'expense_date' => ['required', 'date_format:Y-m-d'],
            'note' => ['nullable', 'string', 'max:255'],
            'split_type' => ['required', Rule::in(['equal', 'exact', 'percent'])],
            'participants' => ['required', 'array', 'min:1', 'max:20'],
            'participants.*.user_id' => ['required', 'integer', 'distinct', Rule::in($memberIds)],
            'participants.*.amount' => [Rule::requiredIf($type === 'exact'), 'integer', 'min:1'],
            'participants.*.percent' => [Rule::requiredIf($type === 'percent'), 'numeric', 'min:0.01', 'max:100'],
        ]);
    }

    private function saveShares(GroupExpense $expense, array $shares): void
    {
        $rows = [];
        foreach ($shares as $userId => $amount) {
            $rows[] = ['user_id' => $userId, 'amount_owed' => $amount];
        }

        $expense->shares()->createMany($rows);
    }
}