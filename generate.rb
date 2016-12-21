require 'randomext'
require 'open3'
require 'pstore'
include Math

# メソッド宣言
def get_bandwidth_rand
  i = rand(0...4)
  case i
    when 0 then
      return 10
    when 1 then
      return 20
    when 2 then
      return 30
    when 3 then
      return 40
    else
      return 10
  end
end

def get_quality_rand
  1
end

def get_nodes_rand(node_size)
  start_node = rand(1..node_size)
  begin
    end_node = rand(1..node_size)
  end while start_node == end_node
  [start_node, end_node]
end

def get_failure_rate_rand
  rand(0..0.03)
end

def write_log(message)
  log_file = File.open(LOG_FILE, "a")
  log_file.print(message)
  log_file.close
end

def load_topology(filepath, link_list)
  topology = File.open(filepath)
  node_size = 0
  i = 0
  topology.each_line do |topology_line|
    if i == 0
      node_size = topology_line.to_i
      link_list=Array.new(node_size).map! { Array.new }
    else
      if (match = topology_line.match(/(\d+)\s(\d+)\s(\d+)/))!= nil
        link_list[match[1].to_i-1][match[2].to_i-1] = Link.new(match[1].to_i, match[2].to_i, match[3].to_i, 300, get_failure_rate_rand, 0)
      end
    end
    i = i.succ
  end
  link_list
end

def is_failure(failure_rate)
  failure_rate > rand
end

def is_repaired(ave_repaired_time, failure_time)
  # 修復時間は指数分布
  repaire_probability = 1.0 - exp(-1.0 * (1.0 / ave_repaired_time) * failure_time)
  random = rand
  repaire_probability > random
end

def show_links(link_list)
  bandwidth_str = ""
  link_list.each { |ary|
    ary.each { |link|
      if link != nil && link.failure_status == 0
        bandwidth_str << link.start_node.to_s << " " << link.end_node.to_s << " " << link.bandwidth.to_s << "\n"
      end
    }
  }
  bandwidth_str
end


# 構造体宣言
Link = Struct.new(:start_node, :end_node, :distance, :bandwidth, :failure_rate, :failure_status)
Traffic = Struct.new(:id, :holding_time, :bandwidth, :quality, :start_node, :end_node)
ActiveTraffic = Struct.new(:end_time, :traffic, :routes)

GLPK_PATH = "C:\\Users\\shugonta\\Documents\\gusek\\glpsol.exe"
TOPOLOGY_FILE = 'topology.txt'
DATA_FILE = "routing_test.dat"
OUTPUT_FILE = "routing_test.out"
LOG_FILE = "log.txt"

# トポロジー読み込み
node_size = 0
random = Random.new
link_list = []
link_list = load_topology(TOPOLOGY_FILE, link_list)
node_size = link_list.size

# 初期設定生成
#リンク条件生成


#トラフィック要求発生
TRAFFIC_DEMAND = 25 #一秒当たりの平均トラフィック発生量
HOLDING_TIME = 4 #平均トラフィック保持時間
TOTAL_TRAFFIC = 1000 #総トラフィック量
MAX_ROUTE = 3 #一つの要求に使用される最大ルート数
AVERAGE_REPAIRED_TIME = 5


traffic_list = []
traffic_count = 0
second = 0

begin
  traffic_per_second = random.poisson(TRAFFIC_DEMAND)
  traffic_list << []
  for num in 0...traffic_per_second.round
    nodes = get_nodes_rand(node_size)
    traffic_list[second] << Traffic.new(traffic_count, random.exponential(HOLDING_TIME - 1).round + 1, get_bandwidth_rand, get_quality_rand, nodes[0], nodes[1])
    traffic_count = traffic_count.succ
    if traffic_count == TOTAL_TRAFFIC
      break
    end
  end
  second = second.succ
end while traffic_count < TOTAL_TRAFFIC
puts second

# 条件保存
link_list_str = Marshal.dump(link_list)
traffic_list_str = Marshal.dump(traffic_list)
f = File.open('link_list.txt','wb')
f.print(link_list_str)
f.close
f = File.open('traffic_list.txt','wb')
f.print(traffic_list_str)
f.close