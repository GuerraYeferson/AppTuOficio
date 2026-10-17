<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\WorkerProfile;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class WorkerController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $query = WorkerProfile::with('trades:id,name')
            ->where('is_available', true);

        if ($request->filled('trade_id')) {
            $tradeId = $request->integer('trade_id');
            $query->whereHas('trades', function ($q) use ($tradeId) {
                $q->where('trades.id', $tradeId);
            });
        }

        if ($request->filled('district')) {
            $query->where('district', 'like', '%' . $request->string('district') . '%');
        }

        if ($request->filled('search')) {
            $search = $request->string('search');
            $query->where(function ($q) use ($search) {
                $q->where('first_name', 'like', "%{$search}%")
                  ->orWhere('last_name', 'like', "%{$search}%");
            });
        }

        $workers = $query->orderBy('first_name')->paginate(10);

        return response()->json($workers);
    }

    public function show(int $id): JsonResponse
    {
        $worker = WorkerProfile::with('trades:id,name')->find($id);

        if (! $worker) {
            return response()->json(['message' => 'Trabajador no encontrado'], 404);
        }

        return response()->json(['worker' => $worker]);
    }
}