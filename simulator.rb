require 'randomext'

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
  rand = Random.new
  rand.po
end

# 構造体宣言
Link = Struct.new(:start_node, :end_node, :distance, :bandwidth, :failure_rate)
Traffic = Struct.new(:holding_time, :bandwidth, :quality, :start_node, :end_node)


# トポロジー読み込み
topology = File.open('topology.txt')
topology_array = []
node_size = 0
random = Random.new
i = 0
topology.each_line do |topology_line|
  if i == 0
    node_size = topology_line.to_i
  else
    if (match = topology_line.match(/(\d+)\s(\d+)\s(\d+)/))!= nil
      topology_array << Link.new(match[1], match[2], match[3], 100,)
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
  for num in 0..traffic_per_second
    nodes = get_nodes_rand(node_size)
    traffic_list[second] << Traffic.new(random.exponential(HOLDING_TIME - 1).round + 1, get_bandwidth_rand, get_quality_rand, nodes[0], nodes[1])
    traffic_count = traffic_count.succ
    if traffic_count == TOTAL_TRAFFIC
      break
    end
  end
  second = second.succ
end while traffic_count < TOTAL_TRAFFIC
# puts second


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
