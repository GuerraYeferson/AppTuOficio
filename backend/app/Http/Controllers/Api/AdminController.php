<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\JobPost;
use App\Models\Trade;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class AdminController extends Controller
{
    // =====================================================
    // USUARIOS
    // =====================================================
    public function users(Request $request): JsonResponse
    {
        $query = User::with(['clientProfile', 'workerProfile.trades:id,name'])
            ->where('role', '!=', 'admin');

        if (in_array($request->query('role'), ['client', 'worker'], true)) {
            $query->where('role', $request->query('role'));
        }

        if ($request->filled('search')) {
            $s = $request->string('search')->toString();

            $query->where(function ($q) use ($s) {
                $q->where('email', 'like', "%{$s}%")
                    ->orWhere('name', 'like', "%{$s}%")
                    ->orWhereHas('clientProfile', fn ($c) => $c
                        ->where('first_name', 'like', "%{$s}%")
                        ->orWhere('last_name', 'like', "%{$s}%"))
                    ->orWhereHas('workerProfile', fn ($w) => $w
                        ->where('first_name', 'like', "%{$s}%")
                        ->orWhere('last_name', 'like', "%{$s}%"));
            });
        }

        $users = $query->latest()->paginate(15);
        $users->through(fn (User $u) => $this->userData($u));

        return response()->json($users);
    }

    public function showUser(int $id): JsonResponse
    {
        $user = User::with(['clientProfile', 'workerProfile.trades:id,name'])
            ->where('role', '!=', 'admin')
            ->find($id);

        if (! $user) {
            return response()->json(['message' => 'Usuario no encontrado'], 404);
        }

        $data = $this->userData($user);
        $data['job_posts_count'] = $user->jobPosts()->count();

        return response()->json(['user' => $data]);
    }

    public function suspendUser(Request $request, int $id): JsonResponse
    {
        return $this->setUserActive($request, $id, false);
    }

    public function reactivateUser(Request $request, int $id): JsonResponse
    {
        return $this->setUserActive($request, $id, true);
    }

    private function setUserActive(Request $request, int $id, bool $active): JsonResponse
    {
        $user = User::find($id);

        if (! $user) {
            return response()->json(['message' => 'Usuario no encontrado'], 404);
        }

        if ($user->isAdmin() || $user->id === $request->user()->id) {
            return response()->json([
                'message' => 'No puedes cambiar el estado de un administrador',
            ], 403);
        }

        $user->is_active = $active;
        $user->save();

        if (! $active) {
            $user->tokens()->delete(); // cierra sus sesiones abiertas
        }

        return response()->json([
            'message' => $active ? 'Cuenta reactivada' : 'Cuenta suspendida',
            'is_active' => $active,
        ]);
    }

    private function userData(User $user): array
    {
        return [
            'id' => $user->id,
            'name' => $user->name,
            'email' => $user->email,
            'role' => $user->role,
            'is_active' => $user->is_active,
            'created_at' => $user->created_at,
            'profile' => $user->isWorker() ? $user->workerProfile : $user->clientProfile,
        ];
    }

    // =====================================================
    // ANUNCIOS
    // =====================================================
    public function jobPosts(Request $request): JsonResponse
    {
        $query = JobPost::with([
            'trade:id,name',
            'user.clientProfile:id,user_id,first_name,last_name,phone',
        ]);

        if (in_array($request->query('status'), ['open', 'in_progress', 'closed'], true)) {
            $query->where('status', $request->query('status'));
        }

        return response()->json($query->latest()->paginate(15));
    }

    public function closeJobPost(int $id): JsonResponse
    {
        $post = JobPost::find($id);

        if (! $post) {
            return response()->json(['message' => 'Anuncio no encontrado'], 404);
        }

        $post->update(['status' => 'closed']);

        return response()->json(['message' => 'Anuncio cerrado']);
    }

    public function deleteJobPost(int $id): JsonResponse
    {
        $post = JobPost::find($id);

        if (! $post) {
            return response()->json(['message' => 'Anuncio no encontrado'], 404);
        }

        $post->delete();

        return response()->json(['message' => 'Anuncio eliminado correctamente']);
    }

    // =====================================================
    // OFICIOS (no se eliminan, se activan o desactivan)
    // =====================================================
    public function trades(): JsonResponse
    {
        return response()->json([
            'trades' => Trade::orderBy('name')->get(['id', 'name', 'is_active']),
        ]);
    }

    public function storeTrade(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:100', 'unique:trades,name'],
        ]);

        $trade = Trade::create($data)->refresh();

        return response()->json([
            'message' => 'Oficio creado correctamente',
            'trade' => $trade,
        ], 201);
    }

    public function updateTrade(Request $request, int $id): JsonResponse
    {
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

    public function toggleTrade(int $id): JsonResponse
    {
        $trade = Trade::find($id);

        if (! $trade) {
            return response()->json(['message' => 'Oficio no encontrado'], 404);
        }

        $trade->is_active = ! $trade->is_active;
        $trade->save();

        return response()->json([
            'message' => $trade->is_active ? 'Oficio activado' : 'Oficio desactivado',
            'trade' => $trade,
        ]);
    }
}