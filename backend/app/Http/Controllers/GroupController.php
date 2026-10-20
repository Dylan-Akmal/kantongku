<?php

namespace App\Http\Controllers;

use App\Http\Resources\GroupResource;
use App\Models\SplitGroup;
use App\Services\GroupBalanceService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\DB;

class GroupController extends Controller
{
    private const MAX_MEMBERS = 20;

    public function index(Request $request): AnonymousResourceCollection
    {
        $groups = $request->user()->groups()
            ->with('owner:id,name')
            ->withCount('members')
            ->orderByDesc('split_groups.id')
            ->get();

        return GroupResource::collection($groups);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:60'],
        ]);

        $user = $request->user();

        $group = DB::transaction(function () use ($user, $data) {
            $group = SplitGroup::create([
                'owner_id' => $user->id,
                'name' => $data['name'],
                'invite_code' => $this->newCode(),
            ]);

            $group->memberships()->create([
                'user_id' => $user->id,
                'role' => 'owner',
            ]);

            return $group;
        });

        return (new GroupResource($this->loadFor($request, $group->id)))
            ->additional(['message' => 'Grup berhasil dibuat.'])
            ->response()
            ->setStatusCode(201);
    }

    public function show(Request $request, string $id): GroupResource
    {
        return new GroupResource($this->loadFor($request, $id));
    }

    public function update(Request $request, string $id): GroupResource
    {
        $group = $this->loadFor($request, $id);
        $this->ensureOwner($group);

        $data = $request->validate([
            'name' => ['required', 'string', 'max:60'],
        ]);

        $group->update($data);

        return (new GroupResource($this->loadFor($request, $id)))
            ->additional(['message' => 'Grup berhasil diperbarui.']);
    }

    public function destroy(Request $request, string $id): JsonResponse
    {
        $group = $this->loadFor($request, $id);
        $this->ensureOwner($group);

        $group->delete();

        return response()->json([
            'message' => 'Grup berhasil dihapus.',
        ]);
    }

    public function join(Request $request): JsonResponse
    {
        $data = $request->validate([
            'invite_code' => ['required', 'string', 'max:12'],
        ]);

        $user = $request->user();
        $group = SplitGroup::where('invite_code', strtoupper(trim($data['invite_code'])))->first();

        if (! $group) {
            return response()->json([
                'message' => 'Kode undangan tidak valid.',
                'errors' => ['invite_code' => ['Kode undangan tidak valid.']],
            ], 422);
        }

        if ($group->memberships()->where('user_id', $user->id)->exists()) {
            return response()->json([
                'message' => 'Kamu sudah menjadi anggota grup ini.',
            ], 409);
        }

        if ($group->memberships()->count() >= self::MAX_MEMBERS) {
            return response()->json([
                'message' => 'Grup sudah penuh (maksimal '.self::MAX_MEMBERS.' anggota).',
            ], 422);
        }

        $group->memberships()->create([
            'user_id' => $user->id,
            'role' => 'member',
        ]);

        return (new GroupResource($this->loadFor($request, $group->id)))
            ->additional(['message' => 'Berhasil bergabung ke grup.'])
            ->response();
    }

    public function regenerateCode(Request $request, string $id): GroupResource
    {
        $group = $this->loadFor($request, $id);
        $this->ensureOwner($group);

        $group->update(['invite_code' => $this->newCode()]);

        return (new GroupResource($this->loadFor($request, $id)))
            ->additional(['message' => 'Kode undangan berhasil dibuat ulang.']);
    }

    public function leave(Request $request, string $id, GroupBalanceService $balances): JsonResponse
    {
        $group = $this->loadFor($request, $id);
        $user = $request->user();

        if ($group->pivot->role === 'owner') {
            return response()->json([
                'message' => 'Pemilik tidak bisa keluar dari grup. Hapus grup jika tidak dipakai lagi.',
            ], 422);
        }

        if ($balances->balanceOf($group, $user->id) !== 0) {
            return response()->json([
                'message' => 'Saldomu di grup ini belum nol. Lunasi dulu sebelum keluar.',
            ], 409);
        }

        $group->memberships()->where('user_id', $user->id)->delete();

        return response()->json([
            'message' => 'Kamu telah keluar dari grup.',
        ]);
    }

    public function removeMember(Request $request, string $id, string $userId, GroupBalanceService $balances): JsonResponse
    {
        $group = $this->loadFor($request, $id);
        $this->ensureOwner($group);

        if ((int) $userId === $request->user()->id) {
            return response()->json([
                'message' => 'Pemilik tidak bisa mengeluarkan dirinya sendiri.',
            ], 422);
        }

        $member = $group->memberships()->where('user_id', $userId)->firstOrFail();

        if ($balances->balanceOf($group, (int) $userId) !== 0) {
            return response()->json([
                'message' => 'Saldo anggota ini di grup belum nol, jadi belum bisa dikeluarkan.',
            ], 409);
        }

        $member->delete();

        return response()->json([
            'message' => 'Anggota berhasil dikeluarkan.',
        ]);
    }

    private function loadFor(Request $request, string|int $id): SplitGroup
    {
        return $request->user()->groups()
            ->where('split_groups.id', $id)
            ->with(['owner:id,name', 'members'])
            ->withCount('members')
            ->firstOrFail();
    }

    private function ensureOwner(SplitGroup $group): void
    {
        abort_unless(
            $group->pivot?->role === 'owner',
            403,
            'Hanya pemilik grup yang boleh melakukan ini.'
        );
    }

    private function newCode(): string
    {
        // Tanpa huruf/angka yang mudah tertukar (0, O, 1, I) agar mudah diketik.
        $alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

        do {
            $code = '';
            for ($i = 0; $i < 8; $i++) {
                $code .= $alphabet[random_int(0, strlen($alphabet) - 1)];
            }
        } while (SplitGroup::where('invite_code', $code)->exists());

        return $code;
    }
}