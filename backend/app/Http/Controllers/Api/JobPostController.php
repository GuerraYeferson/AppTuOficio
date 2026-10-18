<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\JobPost;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class JobPostController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $user = $request->user();

        $query = JobPost::with([
            'trade:id,name',
            'user.clientProfile:id,user_id,first_name,last_name',
        ]);

        if ($user->isClient()) {
            $query->where('user_id', $user->id);
        }else{
            $query->where('status', 'open') 
                ->whereHas('user', fn ($q) => $q->where('is_active', true));
        }
        
        if ($request->filled('trade_id')) {
            $query->where('trade_id', $request->integer('trade_id'));
        }

        if ($request->filled('district')) {
            $query->where('district', 'like', '%' . $request->string('district') . '%');
        }

        if ($request->filled('urgency')) {
            $query->where('urgency', $request->string('urgency'));
        }

        $posts = $query->latest()->paginate(10);

        return response()->json($posts);
    }

    public function store(Request $request): JsonResponse
    {
        $user = $request->user();

        if (! $user->isClient()) {
            return response()->json(['message' => 'Solo los clientes pueden crear anuncios'], 403);
        }

        if (! $user->clientProfile()->exists()) {
            return response()->json(['message' => 'Primero completa tu perfil'], 403);
        }

        $data = $request->validate($this->rules());
        $data = $this->cleanData($data);
        $data['district'] = $user->clientProfile->district; // viene del perfil

        $post = $user->jobPosts()->create($data);
        $post->load('trade:id,name');

        return response()->json([
            'message' => 'Anuncio creado correctamente',
            'job_post' => $post,
        ], 201);
    }

    public function show(Request $request, int $id): JsonResponse
    {
        $post = JobPost::with([
            'trade:id,name',
            'user.clientProfile:id,user_id,first_name,last_name,district',
        ])->find($id);

        if (! $post) {
            return response()->json(['message' => 'Anuncio no encontrado'], 404);
        }

        $user = $request->user();
        $isOwner = $post->user_id === $user->id;

        if (! $isOwner && ! ($user->isWorker() && $post->status === 'open')) {
            return response()->json(['message' => 'No tienes acceso a este anuncio'], 403);
        }

        return response()->json(['job_post' => $post]);
    }

    public function update(Request $request, int $id): JsonResponse
    {
        $post = JobPost::find($id);

        if (! $post) {
            return response()->json(['message' => 'Anuncio no encontrado'], 404);
        }

        if ($post->user_id !== $request->user()->id) {
            return response()->json(['message' => 'No puedes editar este anuncio'], 403);
        }

        $data = $request->validate($this->rules(true));
        $data = $this->cleanData($data);

        $post->update($data);
        $post->load('trade:id,name');

        return response()->json([
            'message' => 'Anuncio actualizado correctamente',
            'job_post' => $post,
        ]);
    }

    public function destroy(Request $request, int $id): JsonResponse
    {
        $post = JobPost::find($id);

        if (! $post) {
            return response()->json(['message' => 'Anuncio no encontrado'], 404);
        }

        if ($post->user_id !== $request->user()->id) {
            return response()->json(['message' => 'No puedes eliminar este anuncio'], 403);
        }

        $post->delete();

        return response()->json(['message' => 'Anuncio eliminado correctamente']);
    }

    private function rules(bool $isUpdate = false): array
    {
        $rules = [
            'title' => ['required', 'string', 'max:120'],
            'description' => ['required', 'string', 'max:2000'],
            'trade_id' => ['nullable', 'integer', 'exists:trades,id', 'required_without:other_trade'],
            'other_trade' => ['nullable', 'string', 'max:100', 'required_without:trade_id'],
            'budget' => ['nullable', 'numeric', 'min:0', 'max:99999999'],
            'location_link' => ['nullable', 'url', 'max:500'],
            'urgency' => ['required', 'in:urgent,scheduled'],
            'desired_date' => ['nullable', 'date', 'after_or_equal:today'],
        ];

        if ($isUpdate) {
            $rules['status'] = ['sometimes', 'in:open,in_progress,closed'];
        }

        return $rules;
    }

    private function cleanData(array $data): array
    {
        // Si eligió un oficio de la lista, se ignora el campo "otro"
        if (! empty($data['trade_id'])) {
            $data['other_trade'] = null;
        } else {
            $data['trade_id'] = null;
        }

        // Si es urgente, no tiene fecha programada
        if (($data['urgency'] ?? null) === 'urgent') {
            $data['desired_date'] = null;
        }

        return $data;
    }
}