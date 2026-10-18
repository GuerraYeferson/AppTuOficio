<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Trade;
use Illuminate\Http\JsonResponse;

class TradeController extends Controller
{
    public function index(): JsonResponse
    {
        return response()->json([
            'trades' => Trade::where('is_active', true)
                ->orderBy('name')
                ->get(['id', 'name']),
        ]);
    }
}