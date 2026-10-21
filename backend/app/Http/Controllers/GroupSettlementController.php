<?php

namespace App\Http\Controllers;

use App\Http\Resources\SettlementResource;
use App\Models\Settlement;
use App\Models\SplitGroup;
use App\Services\GroupBalanceService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class GroupSettlementController extends Controller
{
    public function store(Request $request, string $id, GroupBalanceService $balances): JsonResponse
    {
        $group = $this->groupFor($request, $id);
        $user = $request->user();
        $memberIds = $group->memberships()->pluck('user_id')->all();

        $data = $request->validate([
            'to_user_id' => ['required', 'integer', Rule::in($memberIds), Rule::notIn([$user->id])],
            'amount' => ['required', 'integer', 'min:1', 'max:999999999999'],
            'note' => ['nullable', 'string', 'max:255'],
        ]);

        $toId = (int) $data['to_user_id'];
        $amount = (int) $data['amount'];

        $current = $balances->balances($group);
        $myDebt = max(0, -($current[$user->id] ?? 0));
        $theirCredit = max(0, $current[$toId] ?? 0);

        if ($myDebt === 0) {
            $this->reject('Kamu tidak punya utang di grup ini.');
        }

        if ($theirCredit === 0) {
            $this->reject('Anggota tujuan tidak sedang menunggu pembayaran.');
        }

        if ($amount > $myDebt) {
            $this->reject("Nominal melebihi utangmu ($myDebt).");
        }

        if ($amount > $theirCredit) {
            $this->reject("Nominal melebihi yang harus diterima penerima ($theirCredit).");
        }

        $settlement = new Settlement([
            'group_id' => $group->id,
            'from_user_id' => $user->id,
            'to_user_id' => $toId,
            'amount' => $amount,
            'note' => $data['note'] ?? null,
            'settled_at' => now(),
        ]);
        $settlement->created_at = now();
        $settlement->save();

        $settlement = $settlement->fresh(['fromUser:id,name', 'toUser:id,name']);

        return (new SettlementResource($settlement))
            ->additional([
                'message' => 'Pelunasan berhasil dicatat.',
                'meta' => ['my_balance' => $balances->balanceOf($group, $user->id)],
            ])
            ->response()
            ->setStatusCode(201);
    }

    public function destroy(Request $request, string $id, string $settlementId): JsonResponse
    {
        $group = $this->groupFor($request, $id);
        $settlement = $group->settlements()->findOrFail($settlementId);

        $isOwner = $group->pivot?->role === 'owner';
        $isPayer = (int) $settlement->from_user_id === (int) $request->user()->id;

        abort_unless(
            $isOwner || $isPayer,
            403,
            'Hanya pembuat pelunasan atau pemilik grup yang boleh menghapusnya.'
        );

        $settlement->delete();

        return response()->json([
            'message' => 'Pelunasan berhasil dihapus.',
        ]);
    }

    private function groupFor(Request $request, string $id): SplitGroup
    {
        return $request->user()->groups()
            ->where('split_groups.id', $id)
            ->firstOrFail();
    }

    private function reject(string $message): never
    {
        throw ValidationException::withMessages([
            'amount' => [$message],
        ]);
    }
}