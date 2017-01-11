require 'randomext'
require 'open3'
require 'pstore'
include Math

# メソッド宣言
def write_log(message)
  log_file = File.open(LOG_FILE, "a")
  log_file.print(message)
  log_file.close
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
        bandwidth_str << link.start_node.to_s << " " << link.end_node.to_s << " " << link.bandwidth.to_s << " " << link.failure_rate.to_s << "\n"
      end
    }
  }
  bandwidth_str
end

def show_links_wR(link_list, traffic_item)
  bandwidth_str = ""
  link_list.each { |ary|
    ary.each { |link|
      if link != nil && link.failure_status == 0
        bandwidth_str << link.start_node.to_s << " " << link.end_node.to_s << " " << link.bandwidth.to_s << " " << exp(-1 * link.failure_rate * traffic_item.holding_time).to_s << "\n"
      end
    }
  }
  bandwidth_str
end

def get_nodes_rand(node_size)
  start_node = rand(1..node_size)
  begin
    end_node = rand(1..node_size)
  end while start_node == end_node
  [start_node, end_node]
end

def get_failure_rate_rand
  i = rand(0...3)
  case i
    when 0 then
      return 0.01
    when 1 then
      return 0.02
    when 2 then
      return 0.03
    else
      return 0.01
  end
end

def get_bandwidth_rand
  100
end

def get_quality_rand
  1
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
      if (match = topology_line.match(/(\d+)\s(\d+)\s(\d+)\s([\d.]+)/))!= nil
        link_list[match[1].to_i-1][match[2].to_i-1] = Link.new(match[1].to_i, match[2].to_i, match[3].to_i, 10000, match[4].to_f, 0)
      end
    end
    i = i.succ
  end
  link_list
end


# 構造体宣言
Link = Struct.new(:start_node, :end_node, :distance, :bandwidth, :failure_rate, :failure_status)
Traffic = Struct.new(:id, :holding_time, :bandwidth, :quality, :start_node, :end_node)
ActiveTraffic = Struct.new(:end_time, :traffic, :routes)
Define = Struct.new(:traffic_demand, :holding_time, :total_traffic, :max_route, :average_repaired_time)

# GLPK_PATH = "C:\\Users\\shugonta\\Documents\\gusek\\glpsol.exe"
GLPK_PATH = "glpsol"
DATA_FILE = "routing_test.dat"
OUTPUT_FILE = "routing_test.out"
LOG_FILE = "log_cost.txt"
RESULT_FILE = "result_cost.txt"
CPLEX_PATH = "cplex"
CPLEX_LP = "cplex.lp"
CPLEX_SCRIPT = "cplex.txt"
TOPOLOGY_FILE = 'topology_mesh_with_failure.txt'
COUNT = 1
HOLDING_TIME = 1 #平均トラフィック保持時間
MAX_ROUTE = 3 #一つの要求に使用される最大ルート数
REPEAT_MAX = 8
INT_MAX = 2147483647

# トポロジー読み込み
node_size = 0
random = Random.new
link_list = []
link_list = load_topology(TOPOLOGY_FILE, link_list)
node_size = link_list.size

cost_propose_total = 0
cost_mincostflow_total = 0

for i in 1..COUNT do
#   トラフィック条件生成
#   nodes = get_nodes_rand(node_size)
  nodes =[1, 9]
  # traffic_item = Traffic.new(0, random.exponential(HOLDING_TIME - 1).round + 1, get_bandwidth_rand, get_quality_rand, nodes[0], nodes[1])
  traffic_item = Traffic.new(0, HOLDING_TIME, get_bandwidth_rand, get_quality_rand, nodes[0], nodes[1])
  write_log(show_links_wR(link_list, traffic_item))
  #   提案手法実行
  #GLPK用データファイル作成
  #GLPK変数定義
  data_file = File.open(DATA_FILE, "w")
  data_file.puts("param N := " << node_size.to_s << " ;")
  data_file.puts("param M := " << MAX_ROUTE.to_s << " ;")
  data_file.puts("param p := " << traffic_item.start_node.to_s << " ;")
  data_file.puts("param q := " << traffic_item.end_node.to_s << " ;")
  data_file.puts("param B := " << traffic_item.bandwidth.to_s << " ;")
  data_file.puts("param Q := " << traffic_item.quality.to_s << " ;")
  distance_str = ""
  bandwidth_str = ""
  reliability_str = ""
  bandwidth_max = 0
  #リンク、距離定義
  link_list.each { |ary|
    ary.each { |link|
      if link != nil && link.failure_status == 0
        distance_str << link.start_node.to_s << " " << link.end_node.to_s << " " << link.distance.to_s << "\n"
        bandwidth_str << link.start_node.to_s << " " << link.end_node.to_s << " " << link.bandwidth.to_s << "\n"
        reliability_str << link.start_node.to_s << " " << link.end_node.to_s << " " << sprintf("%.4f", exp(-1 * link.failure_rate * traffic_item.holding_time)) << "\n"
        bandwidth_max = [link.bandwidth, bandwidth_max].max
      end
    }
  }
  data_file.puts("param C_MAX := " << bandwidth_max.to_s << " ;")
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
  glpk_path = GLPK_PATH + (" -m routing.mod -o " << OUTPUT_FILE << " -d " << DATA_FILE << " --wlpt " << CPLEX_LP << " --check")
  o, e, s = Open3.capture3(glpk_path)
  if o.match(/^Model has been successfully generated$/) != nil
    cplex_path = CPLEX_PATH + (" < " << CPLEX_SCRIPT)
    o2, e2, s2 = Open3.capture3(cplex_path)
    if o2.match(/Integer optimal/) != nil
      if (match = o2.match(/Objective\s+=\s+([\d\.]+)e\+(\d+)/))== nil
        puts "No Objective"
        exit
      end
      puts match[1] + "* 10^" + match[2]
      puts cost = (match[1].to_f * (10 ** match[2].to_i)).to_i
      write_log(sprintf("[Accepted(%d)] %d->%d (%d, %f) Cost: %d\n", traffic_item.id, traffic_item.start_node, traffic_item.end_node, traffic_item.bandwidth, traffic_item.quality, cost))
      cost_propose_total += cost
      #最適解発見
      route=Array.new(MAX_ROUTE).map! { Array.new }
      o2.scan(/^y\((\d+),(\d+),(\d+)\)\s+(\d+\.\d+)/) do |route_num, start_node, end_node, volume|
        if link_list[start_node.to_i - 1][end_node.to_i - 1] != nil
          if volume.to_i > 0
            route[route_num.to_i - 1] << Link.new(start_node.to_i, end_node.to_i, link_list[start_node.to_i - 1][end_node.to_i - 1].distance, volume.to_i, link_list[start_node.to_i - 1][end_node.to_i - 1].failure_rate, 0)
          end
        else
          puts sprintf("[Error] link %d->%d not found\n", start_node.to_i, end_node.to_i)
        end
      end
      # ルート表示
      route_cnt = 0
      route.each { |route_item|
        if route_item != nil && route_item.size > 0
          route_cnt = route_cnt.succ
          write_log(route_item[0].bandwidth.to_s + ": ")
          route_item.each { |link|
            write_log(sprintf("(%d->%d), ", link.start_node, link.end_node))
          }
          write_log("\n")
        end
      }
    else
      #最適解なし
      puts "Blocked"
      write_log(sprintf("[Blocked(%d)] %d->%d (%d, %f)\n", i, traffic_item.start_node, traffic_item.end_node, traffic_item.bandwidth, traffic_item.quality))
      exit
    end
  else
    #   モデル異常
    puts 'Model Error'
    puts o
    exit
  end

  bandwidth = traffic_item.bandwidth
  min_achived_bandwidth = INT_MAX
  max_not_achived_bandwidth = 0
  cost_result = 0

  for j in 1..REPEAT_MAX do
# 最小費用流問題
#GLPK用データファイル作成
#GLPK変数定義
    data_file = File.open(DATA_FILE, "w")
    data_file.puts("param N := " << node_size.to_s << " ;")
    data_file.puts("param M := " << MAX_ROUTE.to_s << " ;")
    data_file.puts("param p := " << traffic_item.start_node.to_s << " ;")
    data_file.puts("param q := " << traffic_item.end_node.to_s << " ;")
    data_file.puts("param B := " << bandwidth.to_s << " ;")
# data_file.puts("param Q := " << 0.to_s << " ;")
    distance_str = ""
    bandwidth_str = ""
# reliability_str = ""
    bandwidth_max = 0
#リンク、距離定義
    link_list.each { |ary|
      ary.each { |link|
        if link != nil && link.failure_status == 0
          distance_str << link.start_node.to_s << " " << link.end_node.to_s << " " << link.distance.to_s << "\n"
          bandwidth_str << link.start_node.to_s << " " << link.end_node.to_s << " " << link.bandwidth.to_s << "\n"
          # reliability_str << link.start_node.to_s << " " << link.end_node.to_s << " " << sprintf("%.4f", exp(-1 * link.failure_rate * traffic_item.holding_time)) << "\n"
          bandwidth_max = [link.bandwidth, bandwidth_max].max
        end
      }
    }
    data_file.puts("param C_MAX := " << bandwidth_max.to_s << " ;")
    data_file.puts("param : E : d :=")
    data_file.print(distance_str)
    data_file.puts(";")
    data_file.puts("param : c :=")
    data_file.print(bandwidth_str)
# data_file.puts(";")
# data_file.puts("param : R :=")
# data_file.print(reliability_str)
    data_file.puts(";\n")
    data_file.close
    glpk_path = GLPK_PATH + (" -m routing_mincostflow.mod -o " << OUTPUT_FILE << " -d " << DATA_FILE << " --wlpt " << CPLEX_LP << " --check")
    o, e, s = Open3.capture3(glpk_path)
    if o.match(/^Model has been successfully generated$/) != nil
      cplex_path = CPLEX_PATH + (" < " << CPLEX_SCRIPT)
      o2, e2, s2 = Open3.capture3(cplex_path)
      if o2.match(/Integer optimal/) != nil
        if (match = o2.match(/Objective\s+=\s+([\d\.]+)e\+(\d+)/))== nil
          puts "No Objective"
          exit
        end
        cost = (match[1].to_f * (10 ** match[2].to_i)).to_i
        puts cost.to_s
        #最適解発見
        route=Array.new(MAX_ROUTE).map! { Array.new }
        o2.scan(/^y\((\d+),(\d+),(\d+)\)\s+(\d+\.\d+)/) do |route_num, start_node, end_node, volume|
          if link_list[start_node.to_i - 1][end_node.to_i - 1] != nil
            if volume.to_i > 0
              route[route_num.to_i - 1] << Link.new(start_node.to_i, end_node.to_i, link_list[start_node.to_i - 1][end_node.to_i - 1].distance, volume.to_i, link_list[start_node.to_i - 1][end_node.to_i - 1].failure_rate, 0)
            end
          else
            write_log(sprintf("[Error-MinCostFlow] link %d->%d not found\n", start_node.to_i, end_node.to_i))
          end
        end
        write_log(sprintf("[Accepted-MinCostFlow(%d-%d)] %d->%d (%d, %f) Cost: %d\n", i, j, traffic_item.start_node, traffic_item.end_node, bandwidth, traffic_item.quality, cost))
        # ルート使用処理
        route_cnt = 0
        expected_bandwidth = 0
        route.each { |route_item|
          if route_item != nil && route_item.size > 0
            route_cnt = route_cnt.succ
            write_log(route_item[0].bandwidth.to_s + ": ")
            route_reliability = 1
            route_item.each { |link|
              write_log(sprintf("(%d->%d), ", link.start_node, link.end_node))
              route_reliability *= exp(-1 * link.failure_rate * traffic_item.holding_time).round(4)
            }
            write_log("\n")
            expected_bandwidth += route_reliability * route_item[0].bandwidth
          end
        }
        write_log(sprintf("[ExpectedBandwidth-MinCostFlow(%d-%d)] %f\n", i, j, expected_bandwidth.to_s))
        if expected_bandwidth >= traffic_item.quality * traffic_item.bandwidth
          min_achived_bandwidth = [min_achived_bandwidth, bandwidth].min
          cost_result = cost
          if bandwidth <= traffic_item.bandwidth
            break
          end
        else
          max_not_achived_bandwidth =[max_not_achived_bandwidth, bandwidth].max
        end
        if min_achived_bandwidth != INT_MAX
          bandwidth = (max_not_achived_bandwidth + min_achived_bandwidth) / 2
        else
          bandwidth = bandwidth * 2
        end
      else
        #最適解なし
        puts "Blocked"
        write_log(sprintf("[Blocked-MinCostFlow(%d-%d)] %d->%d (%d, %f)\n", i, j, traffic_item.start_node, traffic_item.end_node, bandwidth, traffic_item.quality))
        exit
      end
    else
      #   モデル異常
      puts 'Model Error'
      puts o
      exit
    end
  end
  write_log(sprintf("[FinalCost-MinCostFlow(%d-%d)] Cost: %d\n", i, j, cost_result))
  cost_mincostflow_total += cost_result
end

# シミュレーション終了
result_file = File.open(RESULT_FILE, "a")
result_file.print("\n")
result_file.print("Propose\n")
result_file.print(sprintf("Cost_Average:%d\n", cost_propose_total/COUNT))
result_file.print("minCostFlow\n")
result_file.print(sprintf("Cost_Average:%d\n", cost_mincostflow_total/COUNT))
result_file.print("\n")
result_file.close