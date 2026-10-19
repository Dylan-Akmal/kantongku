<?php

namespace App\Http\Controllers;

use App\Http\Resources\CategoryResource;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Validation\Rule;

class CategoryController extends Controller
{
    private const TYPES = ['income', 'expense'];

    public function index(Request $request): AnonymousResourceCollection
    {
        $request->validate([
            'type' => ['nullable', Rule::in(self::TYPES)],
        ]);

        $categories = $request->user()->categories()
            ->when($request->filled('type'), fn ($q) => $q->where('type', $request->query('type')))
            ->orderBy('type')
            ->orderBy('id')
            ->get();

        return CategoryResource::collection($categories);
    }

    public function store(Request $request): JsonResponse
    {
        $user = $request->user();

        $data = $request->validate([
            'name' => [
                'required', 'string', 'max:50',
                Rule::unique('categories', 'name')->where(
                    fn ($q) => $q->where('user_id', $user->id)->where('type', $request->input('type'))
                ),
            ],
            'type' => ['required', Rule::in(self::TYPES)],
        ]);

        $category = $user->categories()->create($data);

        return (new CategoryResource($category))
            ->additional(['message' => 'Kategori berhasil dibuat.'])
            ->response()
            ->setStatusCode(201);
    }

    public function update(Request $request, string $id): CategoryResource
    {
        $category = $request->user()->categories()->findOrFail($id);

        // Hanya nama yang boleh diubah; tipe dikunci agar transaksi lama tetap bermakna.
        $data = $request->validate([
            'name' => [
                'required', 'string', 'max:50',
                Rule::unique('categories', 'name')->where(
                    fn ($q) => $q->where('user_id', $category->user_id)->where('type', $category->type)
                )->ignore($category->id),
            ],
        ]);

        $category->update($data);

        return (new CategoryResource($category))
            ->additional(['message' => 'Kategori berhasil diperbarui.']);
    }

    public function destroy(Request $request, string $id): JsonResponse
    {
        $category = $request->user()->categories()->findOrFail($id);

        if ($category->transactions()->exists()) {
            return response()->json([
                'message' => 'Kategori sudah dipakai transaksi dan tidak bisa dihapus. Ubah namanya saja.',
            ], 409);
        }

        $category->delete();

        return response()->json([
            'message' => 'Kategori berhasil dihapus.',
        ]);
    }
}