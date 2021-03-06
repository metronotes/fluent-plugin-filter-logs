# frozen_string_literal: true

require 'byebug'
require 'helper'
require 'fluent/plugin/filter_logs.rb'

class LogsFilterTest < Test::Unit::TestCase
  setup do
    Fluent::Test.setup
  end

  def create_driver(conf)
    Fluent::Test::Driver::Filter.new(Fluent::Plugin::LogsFilter).configure(conf)
  end

  def filter(messages, conf = '')
    d = create_driver(conf)
    d.run(default_tag: 'input.access') do
      messages.each do |message|
        d.feed(message)
      end
    end
    d.filtered_records
  end

  test 'basic unformated message' do
    messages = [
      { 'message' => 'This is test message' }
    ]
    expected = [
      { 'message' => 'This is test message' }
    ]
    assert_equal(expected, filter(messages))
  end

  test 'basic fmtlog parsing' do
    messages = [
      { 'message' => 'time="2018-01-01 00:00:00" aaa=111 bbb=222' }
    ]
    expected = [
      { 'message' => 'time="2018-01-01 00:00:00" aaa=111 bbb=222' }
    ]
    assert_equal(expected, filter(messages))
  end

  test 'json fmt logs' do
    text = '{"container_id":"2caa236b7c","container_name":"/traefik-lb_traefik_1","source":"stdout","log":"time=\"2020-03-31T08:46:44Z\" level=debug msg=\"Filtering disabled container\" providerName=docker container=deposit-collection-edge-11facecb13"}'
    messages = [
      JSON.parse(text)
    ]
    expected = [
      {
        'container_id' => '2caa236b7c',
        'container_name' => '/traefik-lb_traefik_1',
        'source' => 'stdout',
        'level' => 'DEBUG',
        'message' => 'Filtering disabled container',
        'providerName' => 'docker',
        'container' => 'deposit-collection-edge-11facecb13',
        'time' => '2020-03-31T08:46:44Z'
      }
    ]
    assert_equal(expected, filter(messages))
  end

  test 'json apache logs (nginx example)' do
    text = '{"container_name":"/demo_frontend_1","source":"stdout","log":"192.168.80.32 - - [27/Mar/2020:19:26:18 +0000] \"GET /static/media/search.f6cf3254.svg HTTP/1.1\" 200 329 \"https://demo.openware.work/trading/copyright/batusdt\" \"Mozilla/5.0 (Linux; Android 8.0.0; SAMSUNG SM-J330FN/J330FNXXS3BSE1) AppleWebKit/537.36 (KHTML, like Gecko) SamsungBrowser/11.1 Chrome/75.0.3770.143 Mobile Safari/537.36\" \"123.456.789.0\"","container_id":"1888b6a06ef7"}'
    messages = [
      JSON.parse(text)
    ]
    expected = [
      {
        'container_id' => '1888b6a06ef7',
        'container_name' => '/demo_frontend_1',
        'content_size' => '329',
        'referer' => 'https://demo.openware.work/trading/copyright/batusdt',
        'message' => 'GET /static/media/search.f6cf3254.svg HTTP/1.1',
        'source' => 'stdout',
        'status_code' => 200,
        'upstream_ip' => '192.168.80.32',
        'user_agent' => 'Mozilla/5.0 (Linux; Android 8.0.0; SAMSUNG SM-J330FN/J330FNXXS3BSE1) AppleWebKit/537.36 (KHTML, like Gecko) SamsungBrowser/11.1 Chrome/75.0.3770.143 Mobile Safari/537.36',
        'user_ip' => '123.456.789.0'
      }
    ]
    assert_equal(expected, filter(messages))
  end

  test 'json apache logs (influx example)' do
    text = '{"source":"stderr","log":"[httpd] 192.168.128.5 - root [31/Mar/2020:08:26:58 +0000] \"GET /query?db=peatio_production&epoch=s&p=%5BREDACTED%5D&precision=s&q=SELECT+%2A+FROM+candles_3d+WHERE+market%3D%27ethusd%27+ORDER+BY+desc+LIMIT+1 HTTP/1.1\" 200 181 \"-\" \"Ruby\" 6371fccd-7329-11ea-aef5-0242c0a8800b 384","container_id":"c0f3b3778","container_name":"/dev01_influxdb_1"}'
    messages = [
      JSON.parse(text)
    ]
    expected = [
      {
        'container_id' => 'c0f3b3778',
        'container_name' => '/dev01_influxdb_1',
        'content_size' => '181',
        'referer' => '-',
        'message' => 'GET /query?db=peatio_production&epoch=s&p=%5BREDACTED%5D&precision=s&q=SELECT+%2A+FROM+candles_3d+WHERE+market%3D%27ethusd%27+ORDER+BY+desc+LIMIT+1 HTTP/1.1',
        'source' => 'stderr',
        'status_code' => 200,
        'upstream_ip' => '192.168.128.5',
        'user_agent' => 'Ruby'
      }
    ]
    assert_equal(expected, filter(messages))
  end

  test 'json vault logs (with level)' do
    text = '{"container_name":"/demo_vault_1","source":"stderr","log":"2020-03-30T09:53:21.323Z [WARNING]  no `api_addr` value specified in config or in VAULT_API_ADDR; falling back to detection if possible, but this value should be manually set","container_id":"4f82763814e"}'
    messages = [
      JSON.parse(text)
    ]
    expected = [
      {
        'container_id' => '4f82763814e',
        'container_name' => '/demo_vault_1',
        'level' => 'WARN',
        'message' => ' no `api_addr` value specified in config or in VAULT_API_ADDR; falling back to detection if possible, but this value should be manually set',
        'source' => 'stderr'
      }
    ]
    assert_equal(expected, filter(messages))
  end

  test 'json vault logs (unformated)' do
    text = '{"container_name":"/demo_vault_1","source":"stdout","log":"Version: Vault v1.3.0","container_id":"4f82763814e"}'
    messages = [
      JSON.parse(text)
    ]
    expected = [
      {
        'container_id' => '4f82763814e',
        'container_name' => '/demo_vault_1',
        'message' => 'Version: Vault v1.3.0',
        'source' => 'stdout'
      }
    ]
    assert_equal(expected, filter(messages))
  end

  test 'json rabbitmq logs' do
    text = '{"source":"stdout","log":"2020-03-30 09:54:51.627 [note] <0.734.0> connection <0.734.0> (192.168.128.5:49388 -> 192.168.128.4:5672): user \'guest\' authenticated and granted access to vhost \'/\'","container_id":"40b5e1bde","container_name":"/dev01_rabbitmq_1"}'
    messages = [
      JSON.parse(text)
    ]

    expected = [
      {
        'container_id' => '40b5e1bde',
        'container_name' => '/dev01_rabbitmq_1',
        'message' => '<0.734.0> connection <0.734.0> (192.168.128.5:49388 -> 192.168.128.4:5672): user \'guest\' authenticated and granted access to vhost \'/\'',
        'source' => 'stdout',
        'level' => 'INFO'
      }
    ]
    assert_equal(expected, filter(messages))
  end

  test 'json ruby (json error simple)' do
    text = '{"container_id":"7d3ac22","container_name":"/dev01_blockchain_1","source":"stderr","log":"{\"level\":\"ERROR\",\"time\":\"2020-03-31 21:54:05\",\"message\":\"#<Peatio::Blockchain::ClientError: Failed to open TCP connection to parity:8545 (getaddrinfo: Name or service not known)>\"}"}'
    messages = [
      JSON.parse(text)
    ]

    expected = [
      {
        'container_id' => '7d3ac22',
        'container_name' => '/dev01_blockchain_1',
        'message' => '#<Peatio::Blockchain::ClientError: Failed to open TCP connection to parity:8545 (getaddrinfo: Name or service not known)>',
        'source' => 'stderr',
        'level' => 'ERROR',
        'time' => '2020-03-31 21:54:05'
      }
    ]
    assert_equal(expected, filter(messages))
  end

  test 'json ruby (json error 2)' do
    text = '{"container_id":"7d3ac22","container_name":"/dev01_blockchain_1","source":"stderr","log":"{\"level\":\"ERROR\",\"time\":\"2020-03-31 21:55:56\",\"message\":\"/home/app/lib/peatio/ethereum/blockchain.rb:60:in `rescue in latest_block_number\'\\\\n/home/app/lib/peatio/ethereum/blockchain.rb:57:in `latest_block_number\'\\\\n/home/app/app/services/blockchain_service.rb:16:in `latest_block_number\'\\\\n/home/app/app/workers/daemons/blockchain.rb:22:in `process\'\\\\n/home/app/app/workers/daemons/blockchain.rb:9:in `block (3 levels) in run\'\"}"}'
    messages = [
      JSON.parse(text)
    ]

    expected = [
      {
        'container_id' => '7d3ac22',
        'container_name' => '/dev01_blockchain_1',
        'message' =>
          "/home/app/lib/peatio/ethereum/blockchain.rb:60:in `rescue in latest_block_number'\n" \
          "/home/app/lib/peatio/ethereum/blockchain.rb:57:in `latest_block_number'\n" \
          "/home/app/app/services/blockchain_service.rb:16:in `latest_block_number'\n" \
          "/home/app/app/workers/daemons/blockchain.rb:22:in `process'\n" \
          "/home/app/app/workers/daemons/blockchain.rb:9:in `block (3 levels) in run'",
        'source' => 'stderr',
        'level' => 'ERROR',
        'time' => '2020-03-31 21:55:56'
      }
    ]
    assert_equal(expected, filter(messages))
  end

  test 'json ruby (logger example debug)' do
    text = '{"container_id":"7d3ac22","container_name":"/dev01_blockchain_1","source":"stderr","log":"D, [2020-04-01T13:04:30.445223 #1] DEBUG -- : received websocket message: [156,\\"te\\",[431756335,1585746269293,0.6,131.83]]"}'
    messages = [
      JSON.parse(text)
    ]

    expected = [
      {
        'container_id' => '7d3ac22',
        'container_name' => '/dev01_blockchain_1',
        'message' => 'received websocket message: [156,"te",[431756335,1585746269293,0.6,131.83]]',
        'source' => 'stderr',
        'level' => 'DEBUG'
      }
    ]
    assert_equal(expected, filter(messages))
  end

  test 'json ruby (logger example info 1)' do
    text = '{"container_id":"7d3ac22","container_name":"/dev01_blockchain_1","source":"stderr","log":"I, [2020-04-01T13:04:30.471779 #1] INFO -- : Publishing trade event: {\\"tid\\"=>431756335, \\"amount\\"=>0.6e0, \\"price\\"=>131.83, \\"date\\"=>1585746269, \\"taker_type\\"=>\\"buy\\"\\}"}'
    messages = [
      JSON.parse(text)
    ]

    expected = [
      {
        'container_id' => '7d3ac22',
        'container_name' => '/dev01_blockchain_1',
        'message' => 'Publishing trade event: {"tid"=>431756335, "amount"=>0.6e0, "price"=>131.83, "date"=>1585746269, "taker_type"=>"buy"}',
        'source' => 'stderr',
        'level' => 'INFO'
      }
    ]
    assert_equal(expected, filter(messages))
  end

  test 'json ruby (logger example info 2)' do
    text = '{"container_id":"7d3ac22","container_name":"/dev01_blockchain_1","source":"stderr","log":"I, [2020-04-01T18:47:00.480183 #1]  INFO -- : [3ce041fb-32f9-462b-950b-34e1ba4904f7] Completed 200 OK in 7ms (Views: 5.6ms | Allocations: 6356)"}'
    messages = [
      JSON.parse(text)
    ]

    expected = [
      {
        'container_id' => '7d3ac22',
        'container_name' => '/dev01_blockchain_1',
        'message' => '[3ce041fb-32f9-462b-950b-34e1ba4904f7] Completed 200 OK in 7ms (Views: 5.6ms | Allocations: 6356)',
        'source' => 'stderr',
        'level' => 'INFO'
      }
    ]
    assert_equal(expected, filter(messages))
  end

  test 'json parity (block imported)' do
    text = '{"container_id":"7d3ac22","container_name":"/dev01_parity_1","source":"stderr","log":"2020-04-02 08:00:53 UTC Verifier #7 INFO import Imported #17687508 0xf356…d999 (0 txs, 0.00 Mgas, 1 ms, 0.58 KiB) + another 1 block(s) containing 0 tx(s)"}'
    messages = [
      JSON.parse(text)
    ]

    expected = [
      {
        'container_id' => '7d3ac22',
        'container_name' => '/dev01_parity_1',
        'message' => 'Verifier #7 INFO import Imported #17687508 0xf356…d999 (0 txs, 0.00 Mgas, 1 ms, 0.58 KiB) + another 1 block(s) containing 0 tx(s)',
        'source' => 'stderr',
        'level' => 'INFO'
      }
    ]
    assert_equal(expected, filter(messages))
  end

  test 'json parity (peer report ok)' do
    text = '{"container_id":"7d3ac22","container_name":"/dev01_parity_1","source":"stderr","log":"2020-04-02 08:00:53 UTC IO Worker #0 INFO import 19/50 peers 6 MiB chain 10 MiB db 0 bytes queue 19 KiB sync RPC: 0 conn, 122 req/s, 856 µs"}'
    messages = [
      JSON.parse(text)
    ]

    expected = [
      {
        'container_id' => '7d3ac22',
        'container_name' => '/dev01_parity_1',
        'message' => 'IO Worker #0 INFO import 19/50 peers 6 MiB chain 10 MiB db 0 bytes queue 19 KiB sync RPC: 0 conn, 122 req/s, 856 µs',
        'peers' => '19',
        'peers_max' => '50',
        'source' => 'stderr',
        'level' => 'INFO'
      }
    ]
    assert_equal(expected, filter(messages))
  end

  test 'json parity (peer report warn)' do
    text = '{"container_id":"7d3ac22","container_name":"/dev01_parity_1","source":"stderr","log":"2020-04-02 08:00:53 UTC IO Worker #0 INFO import 10/50 peers 6 MiB chain 10 MiB db 0 bytes queue 19 KiB sync RPC: 0 conn, 122 req/s, 856 µs"}'
    messages = [
      JSON.parse(text)
    ]

    expected = [
      {
        'container_id' => '7d3ac22',
        'container_name' => '/dev01_parity_1',
        'message' => 'IO Worker #0 INFO import 10/50 peers 6 MiB chain 10 MiB db 0 bytes queue 19 KiB sync RPC: 0 conn, 122 req/s, 856 µs',
        'peers' => '10',
        'peers_max' => '50',
        'source' => 'stderr',
        'level' => 'WARN'
      }
    ]
    assert_equal(expected, filter(messages))
  end

  test 'json parity (peer report error)' do
    text = '{"container_id":"7d3ac22","container_name":"/dev01_parity_1","source":"stderr","log":"2020-04-02 08:00:53 UTC IO Worker #0 INFO import 5/50 peers 6 MiB chain 10 MiB db 0 bytes queue 19 KiB sync RPC: 0 conn, 122 req/s, 856 µs"}'
    messages = [
      JSON.parse(text)
    ]

    expected = [
      {
        'container_id' => '7d3ac22',
        'container_name' => '/dev01_parity_1',
        'message' => 'IO Worker #0 INFO import 5/50 peers 6 MiB chain 10 MiB db 0 bytes queue 19 KiB sync RPC: 0 conn, 122 req/s, 856 µs',
        'peers' => '5',
        'peers_max' => '50',
        'source' => 'stderr',
        'level' => 'ERROR'
      }
    ]
    assert_equal(expected, filter(messages))
  end

  test 'json ranger metrics 1' do
    text = '{"container_id":"7d3ac22","container_name":"/dev01_ranger_1","source":"stderr","log":"ranger_connections_total{auth=\\"public\\"}: 44"}'
    messages = [
      JSON.parse(text)
    ]

    expected = [
      {
        'container_id' => '7d3ac22',
        'container_name' => '/dev01_ranger_1',
        'message' => 'ranger_connections_total{auth="public"}: 44',
        'source' => 'stderr',
        'level' => 'INFO'
      }
    ]
    assert_equal(expected, filter(messages))
  end

  test 'json ranger metrics 2' do
    text = '{"container_id":"7d3ac22","container_name":"/dev01_ranger_1","source":"stderr","log":"ranger_subscriptions_current: 0"}'
    messages = [
      JSON.parse(text)
    ]

    expected = [
      {
        'container_id' => '7d3ac22',
        'container_name' => '/dev01_ranger_1',
        'message' => 'ranger_subscriptions_current: 0',
        'source' => 'stderr',
        'level' => 'INFO'
      }
    ]
    assert_equal(expected, filter(messages))
  end

  test 'container json logs: rails grape debug logs' do
    text = '{"container_id":"7d3ac22","container_name":"/demo_nginx-ingress-controller_1","source":"stderr","log":"{\"date\":\"2020-04-07T08:54:04.892+00:00\",\"severity\":\"WARN\",\"data\":{\"status\":200,\"time\":{\"total\":0.49,\"db\":0,\"view\":0.49},\"method\":\"GET\",\"path\":\"/api/v2/identity/ping\",\"params\":{},\"host\":\"10.24.0.4\",\"response\":[{\"ping\":\"pong\"}],\"ip\":\"\",\"ua\":\"kube-probe/1.14+\",\"headers\":{\"Version\":\"HTTP/1.1\",\"Host\":\"10.24.0.4:8080\",\"User-Agent\":\"kube-probe/1.14+\",\"Accept-Encoding\":\"gzip\",\"Connection\":\"close\",\"X-Forwarded-For\":\"\"}}}"}'
    messages = [
      JSON.parse(text)
    ]

    expected = [
      {
        'container_id' => '7d3ac22',
        'container_name' => '/demo_nginx-ingress-controller_1',
        'message' => '{"status":200,"time":{"total":0.49,"db":0,"view":0.49},"method":"GET","path":"/api/v2/identity/ping","params":{},"host":"10.24.0.4","response":[{"ping":"pong"}],"ip":"","ua":"kube-probe/1.14+","headers":{"Version":"HTTP/1.1","Host":"10.24.0.4:8080","User-Agent":"kube-probe/1.14+","Accept-Encoding":"gzip","Connection":"close","X-Forwarded-For":""}}',
        'source' => 'stderr',
        'status_code' => 200,
        'date' => '2020-04-07T08:54:04.892+00:00',
        'severity' => 'WARN',
        'level' => 'DEBUG'
      }
    ]
    assert_equal(expected, filter(messages))
  end

  test 'container json logs: nginx-ingress-controller INFO' do
    text = '{"container_id":"7d3ac22","container_name":"/demo_nginx-ingress-controller_1","source":"stderr","log":"I0406 13:28:52.745452 12 store.go:447] secret core-app/demo-openware-com-tls was updated and it is used in ingress annotations. Parsing..."}'
    messages = [
      JSON.parse(text)
    ]

    expected = [
      {
        'container_id' => '7d3ac22',
        'container_name' => '/demo_nginx-ingress-controller_1',
        'message' => '12 store.go:447] secret core-app/demo-openware-com-tls was updated and it is used in ingress annotations. Parsing...',
        'source' => 'stderr',
        'level' => 'INFO'
      }
    ]
    assert_equal(expected, filter(messages))
  end

  test 'container json logs: nginx-ingress-controller WARN' do
    text = '{"container_id":"7d3ac22","container_name":"/demo_nginx-ingress-controller_1","source":"stderr","log":"W0406 13:28:52.746053      12 backend_ssl.go:46] Error obtaining X.509 certificate: unexpected error creating SSL Cert: certificate and private key does not have a matching public key: tls: private key does not match public key"}'
    messages = [
      JSON.parse(text)
    ]

    expected = [
      {
        'container_id' => '7d3ac22',
        'container_name' => '/demo_nginx-ingress-controller_1',
        'message' => '12 backend_ssl.go:46] Error obtaining X.509 certificate: unexpected error creating SSL Cert: certificate and private key does not have a matching public key: tls: private key does not match public key',
        'source' => 'stderr',
        'level' => 'WARN'
      }
    ]
    assert_equal(expected, filter(messages))
  end

  test 'container json logs: cert-manager INFO' do
    text = '{"container_id":"7d3ac22","container_name":"/cert-manager","source":"stderr","log":"I0407 07:46:06.757038 1 sync.go:445] cert-manager/controller/certificates \"level\"=0 \"msg\"=\"decoding certificate data\" \"related_resource_kind\"=\"CertificateRequest\" \"related_resource_name\"=\"demo-openware-com-tls-391607007\" \"related_resource_namespace\"=\"core-app\" \"resource_kind\"=\"Certificate\" \"resource_name\"=\"demo-openware-com-tls\" \"resource_namespace\"=\"core-app\""}'
    messages = [
      JSON.parse(text)
    ]

    expected = [
      {
        'container_id' => '7d3ac22',
        'container_name' => '/cert-manager',
        'message' => '1 sync.go:445] cert-manager/controller/certificates "level"=0 "msg"="decoding certificate data" "related_resource_kind"="CertificateRequest" "related_resource_name"="demo-openware-com-tls-391607007" "related_resource_namespace"="core-app" "resource_kind"="Certificate" "resource_name"="demo-openware-com-tls" "resource_namespace"="core-app"',
        'source' => 'stderr',
        'level' => 'INFO'
      }
    ]
    assert_equal(expected, filter(messages))
  end
end
