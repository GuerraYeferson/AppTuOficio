<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Trade;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class TradeController extends Controller
{
    public function index(): JsonResponse
    {
        return response()->json([
            'trades' => Trade::orderBy('name')->get(['id', 'name']),
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        if (! $request->user()->isAdmin()) {
            return response()->json(['message' => 'Solo el administrador puede gestionar oficios'], 403);
        }

        $data = $request->validate([
            'name' => ['required', 'string', 'max:100', 'unique:trades,name'],
        ]);

        $trade = Trade::create($data);

        return response()->json([
            'message' => 'Oficio creado correctamente',
            'trade' => $trade,
        ], 201);
    }

    public function update(Request $request, int $id): JsonResponse
    {
        if (! $request->user()->isAdmin()) {
            return response()->json(['message' => 'Solo el administrador puede gestionar oficios'], 403);
        }

        $trade = Trade::find($id);

        if (! $trade) {
            return response()->json(['message' => 'Oficio no encontrado'], 404);
        }

        $data = $request->validate([
            'name' => ['required', 'string', 'max:100', Rule::unique('trades', 'name')->ignore($trade->id)],
        ]);

        $trade->update($data);

        return response()->json([
            'message' => 'Oficio actualizado correctamente',
            'trade' => $trade,
        ]);
    }

    public function destroy(Request $request, int $id): JsonResponse
    {
        if (! $request->user()->isAdmin()) {
            return response()->json(['message' => 'Solo el administrador puede gestionar oficios'], 403);
        }

        $trade = Trade::find($id);

        if (! $trade) {
            return response()->json(['message' => 'Oficio no encontrado'], 404);
        }

        $trade->delete();

        return response()->json(['message' => 'Oficio eliminado correctamente']);
    }
}