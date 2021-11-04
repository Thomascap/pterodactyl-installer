<?php

namespace Pterodactyl\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Ramsey\Uuid\Uuid;
use Illuminate\Support\Str;
use Pterodactyl\Models\Node;
use Illuminate\Contracts\Encryption\Encrypter;
use Illuminate\Support\Facades\Storage;

class NodeCommand extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'command:node {--fqdn=} {--scheme=}';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Command description';

    /**
     * @var \Illuminate\Contracts\Encryption\Encrypter
     */
    private $encrypter;

    /**
     * Create a new command instance.
     *
     * @return void
     */
    public function __construct(Encrypter $encrypter)
    {
        parent::__construct();
        $this->encrypter = $encrypter;
    }

    /**
     * Execute the console command.
     *
     * @return int
     */
    public function handle()
    {
        $uuid = Uuid::uuid4()->toString();
        $daemon_token2 = Str::random(Node::DAEMON_TOKEN_LENGTH);
        $daemon_token = $this->encrypter->encrypt($daemon_token2);
        $daemon_token_id = Str::random(Node::DAEMON_TOKEN_ID_LENGTH);
        $fqdn = $this->option('fqdn');
        $scheme = $this->option('scheme');

        Storage::disk('local')->put('uuid.txt', $uuid);
        Storage::disk('local')->put('daemon_token.txt', $daemon_token2);
        Storage::disk('local')->put('daemon_token_id.txt', $daemon_token_id);

        DB::table('nodes')->insert(['uuid' => $uuid, 'name' => 'Node 01', 'description' => 'Gehost door MyNode', 'location_id' => '1', 'fqdn' => $fqdn, 'scheme' => $scheme, 'behind_proxy' => '0', 'maintenance_mode' => '0', 'memory' => '8000', 'memory_overallocate' => '-1', 'disk' => '80000', 'disk_overallocate' => '-1', 'upload_size' => '100', 'daemon_token_id' => $daemon_token_id, 'daemon_token' => $daemon_token, 'daemonListen' => '8080', 'daemonSFTP' => '2022', 'daemonBase' => '/var/lib/pterodactyl/volumes']);
    }
}