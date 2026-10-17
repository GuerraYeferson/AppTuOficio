<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;

class AuthController extends Controller
{
    public function register(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'email', 'max:255', 'unique:users,email'],
            'password' => ['required', 'string', 'min:8', 'confirmed'],
            'role' => ['required', 'in:client,worker'],
        ]);

        $user = User::create($data);

        $token = $user->createToken('auth_token')->plainTextToken;

        return response()->json([
            'message' => 'Cuenta creada correctamente',
            'token' => $token,
            'user' => $this->userData($user),
        ], 201);
    }

    public function login(Request $request): JsonResponse
    {
        $data = $request->validate([
            'email' => ['required', 'email'],
            'password' => ['required', 'string'],
        ]);

        $user = User::where('email', $data['email'])->first();

        if (! $user || ! Hash::check($data['password'], $user->password)) {
            return response()->json([
                'message' => 'Correo o contraseña incorrectos',
            ], 401);
        }

        $token = $user->createToken('auth_token')->plainTextToken;

        return response()->json([
            'message' => 'Sesión iniciada',
            'token' => $token,
            'user' => $this->userData($user),
        ]);
    }

    public function logout(Request $request): JsonResponse
    {
        $request->user()->currentAccessToken()->delete();

        return response()->json([
            'message' => 'Sesión cerrada',
        ]);
    }

    public function me(Request $request): JsonResponse
    {
        return response()->json([
            'user' => $this->userData($request->user()),
        ]);
    }

    public function destroy(Request $request): JsonResponse
    {
        $data = $request->validate([
            'password' => ['required', 'string'],
        ]);

        $user = $request->user();

        if (! Hash::check($data['password'], $user->password)) {
            return response()->json(['message' => 'La contraseña es incorrecta'], 422);
        }

        $user->tokens()->delete();
        $user->delete();

        return response()->json(['message' => 'Cuenta eliminada correctamente']);
    }

    private function userData(User $user): array
    {
        $profileCompleted = $user->isWorker()
            ? $user->workerProfile()->exists()
            : $user->clientProfile()->exists();

        return [
            'id' => $user->id,
            'name' => $user->name,
            'email' => $user->email,
            'role' => $user->role,
            'profile_completed' => $profileCompleted,
        ];
    }
}