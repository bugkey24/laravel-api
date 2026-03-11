<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\File;
use Illuminate\Support\Facades\Log;

class NodeRegistrationController extends Controller
{
    /**
     * Register a new worker node dynamically.
     */
    public function register(Request $request)
    {
        $workerIp = $request->input('ip') ?? $request->ip();
        
        Log::info("New node attempting to join: $workerIp");

        $nodesFile = storage_path('app/nodes.json');
        $nodes = [];

        if (File::exists($nodesFile)) {
            $nodes = json_decode(File::get($nodesFile), true) ?: [];
        }

        if (!in_array($workerIp, $nodes) && $workerIp !== '127.0.0.1') {
            $nodes[] = $workerIp;
            File::put($nodesFile, json_encode($nodes, JSON_PRETTY_PRINT));
            
            // Trigger Nginx update on the Main Server
            $this->updateNginxConfig($nodes);
        }

        return response()->json([
            'message' => "Node $workerIp registered successfully!",
            'total_nodes' => count($nodes),
            'nodes' => $nodes
        ]);
    }

    /**
     * Update Nginx configuration and reload.
     */
    private function updateNginxConfig($nodes)
    {
        // In this Windows simulation, we call the init.ps1 script 
        // with the updated list of worker nodes.
        $workersList = implode(',', $nodes);
        $command = "powershell.exe -ExecutionPolicy Bypass -File " . base_path('infrastructure/scripts/init.ps1') . " -Workers \"$workersList\"";
        
        // Run in background to avoid blocking the API response
        pclose(popen("start /B $command", "r"));
    }
}
