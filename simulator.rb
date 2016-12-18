require 'randomext'
require "open3"
include Math

# メソッド宣言
def get_bandwidth_rand
  i = rand(0...4)
  case i
    when 0 then
      return 1
    when 1 then
      return 2
    when 2 then
      return 3
    when 3 then
      return 4
    else
      return 1
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
  rand(0..0.02)
end

# 構造体宣言
Link = Struct.new(:start_node, :end_node, :distance, :bandwidth, :failure_rate)
Traffic = Struct.new(:holding_time, :bandwidth, :quality, :start_node, :end_node)

GLPK_PATH = "C:\\Users\\shugonta\\Documents\\gusek\\glpsol.exe"
DATA_FILE = "routing_test.dat"
OUTPUT_FILE = "routing_test.out"

# トポロジー読み込み
topology = File.open('topology.txt')
link_list = []
node_size = 0
random = Random.new
i = 0
topology.each_line do |topology_line|
  if i == 0
    node_size = topology_line.to_i
  else
    if (match = topology_line.match(/(\d+)\s(\d+)\s(\d+)/))!= nil
      link_list << Link.new(match[1].to_i, match[2].to_i, match[3].to_i, 10, get_failure_rate_rand)
    end
  end
  i = i.succ
end

# 初期設定生成
#リンク条件生成


#トラフィック要求発生
TRAFFIC_DEMAND = 10 #一秒当たりの平均トラフィック発生量
HOLDING_TIME = 5 #平均トラフィック保持時間
TOTAL_TRAFFIC = 100 #総トラフィック量


traffic_list = []
traffic_count = 0
second = 0
begin
  traffic_per_second = random.poisson(TRAFFIC_DEMAND)
  traffic_list << []
  for num in 0...traffic_per_second
    nodes = get_nodes_rand(node_size)
    traffic_list[second] << Traffic.new(random.exponential(HOLDING_TIME - 1).round + 1, get_bandwidth_rand, get_quality_rand, nodes[0], nodes[1])
    traffic_count = traffic_count.succ
    if traffic_count == TOTAL_TRAFFIC
      break
    end
  end
  second = second.succ
end while traffic_count < TOTAL_TRAFFIC
puts second

current_link_list = Marshal.load(Marshal.dump(link_list)) #使用可能なリンクリスト

time = 0
begin
  traffic_list[time].each { |traffic_item|
    #GLPK用データファイル作成
    #GLPK変数定義
    data_file = File.open(DATA_FILE, "w")
    data_file.puts("param N := " << node_size.to_s << " ;")
    data_file.puts("param M := 3 ;")
    data_file.puts("param p := " << traffic_item.start_node.to_s << " ;")
    data_file.puts("param q := " << traffic_item.end_node.to_s << " ;")
    data_file.puts("param B := " << traffic_item.bandwidth.to_s << " ;")
    data_file.puts("param Q := " << traffic_item.quality.to_s << " ;")
    distance_str = ""
    bandwidth_str = ""
    reliability_str = ""
    bandwidth_max = 0
    #リンク、距離定義
    current_link_list.each { |link|
      distance_str << link.start_node.to_s << " " << link.end_node.to_s << " " << link.distance.to_s << "\n"
      bandwidth_str << link.start_node.to_s << " " << link.end_node.to_s << " " << link.bandwidth.to_s << "\n"
      reliability_str << link.start_node.to_s << " " << link.end_node.to_s << " " << exp(-1 * link.distance * link.failure_rate * traffic_item.holding_time).to_s << "\n"
      bandwidth_max = [link.bandwidth, bandwidth_max].max
    }
    data_file.puts("param C_MAX := " << 1.to_s << " ;")
    data_file.puts("param : E : d :=")
    data_file.print(distance_str)
    data_file.puts(";")
    data_file.puts("param : c :=")
    data_file.print(bandwidth_str)
    data_file.puts(";")
    data_file.puts("param : R :=")
    data_file.print(reliability_str)
    data_file.puts(";\n")
    data_file.close
    #GLPK実行
    path = GLPK_PATH << " -m routing.mod -o " << OUTPUT_FILE << " -d " << DATA_FILE
    o, e, s = Open3.capture3(path)

  }

end while traffic_list.size > 0


=begin
a = Array.new(1000, 0)
1000.times do
#  a[random.poisson(10)] += 1
  a[random.exponential(HOLDING_TIME - 1).round + 1] += 1
end

mean = 0
1000.times do |i|
  printf("%d %s\n", i, '+'*a[i])
  mean += i * a[i]
end
puts mean.to_f/1000
=end
