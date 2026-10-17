<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ProfileController extends Controller
{
    public function show(Request $request): JsonResponse
    {
        $user = $request->user();

        if ($user->isWorker()) {
            $profile = $user->workerProfile()->with('trades:id,name')->first();
        } else {
            $profile = $user->clientProfile;
        }

        if (! $profile) {
            return response()->json([
                'message' => 'Aún no has completado tu perfil',
                'profile' => null,
            ], 404);
        }

        return response()->json(['profile' => $profile]);
    }

    public function store(Request $request): JsonResponse
    {
        $user = $request->user();

        if ($user->isWorker()) {
            if ($user->workerProfile()->exists()) {
                return response()->json(['message' => 'Tu perfil ya existe, usa la edición'], 409);
            }

            $data = $request->validate($this->workerRules());

            $profile = $user->workerProfile()->create(collect($data)->except('trade_ids')->all());
            $profile->trades()->sync($data['trade_ids'] ?? []);
            $profile->load('trades:id,name');
        } else {
            if ($user->clientProfile()->exists()) {
                return response()->json(['message' => 'Tu perfil ya existe, usa la edición'], 409);
            }

            $data = $request->validate($this->clientRules());
            $profile = $user->clientProfile()->create($data);
        }

        return response()->json([
            'message' => 'Perfil creado correctamente',
            'profile' => $profile,
        ], 201);
    }

    public function update(Request $request): JsonResponse
    {
        $user = $request->user();

        if ($user->isWorker()) {
            $profile = $user->workerProfile;

            if (! $profile) {
                return response()->json(['message' => 'Primero debes crear tu perfil'], 404);
            }

            $data = $request->validate($this->workerRules());

            $profile->update(collect($data)->except('trade_ids')->all());
            $profile->trades()->sync($data['trade_ids'] ?? []);
            $profile->load('trades:id,name');
        } else {
            $profile = $user->clientProfile;

            if (! $profile) {
                return response()->json(['message' => 'Primero debes crear tu perfil'], 404);
            }

            $data = $request->validate($this->clientRules());
            $profile->update($data);
        }

        return response()->json([
            'message' => 'Perfil actualizado correctamente',
            'profile' => $profile,
        ]);
    }

    private function clientRules(): array
    {
        return [
            'first_name' => ['required', 'string', 'max:100'],
            'last_name' => ['required', 'string', 'max:100'],
            'phone' => ['required', 'string', 'max:20'],
            'district' => ['required', 'string', 'max:150'],
        ];
    }

    private function workerRules(): array
    {
        return [
            'first_name' => ['required', 'string', 'max:100'],
            'last_name' => ['required', 'string', 'max:100'],
            'phone' => ['required', 'string', 'max:20'],
            'district' => ['required', 'string', 'max:150'],
            'description' => ['required', 'string', 'max:1000'],
            'years_experience' => ['required', 'integer', 'min:0', 'max:60'],
            'is_available' => ['required', 'boolean'],
            'other_trades' => ['nullable', 'string', 'max:255'],
            'trade_ids' => ['nullable', 'array'],
            'trade_ids.*' => ['integer', 'exists:trades,id'],
        ];
    }
}