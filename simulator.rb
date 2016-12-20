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
        link_list[match[1].to_i-1][match[2].to_i-1] = Link.new(match[1].to_i, match[2].to_i, match[3].to_i, 10, get_failure_rate_rand, 0)
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
  1 - exp(-(1/ave_repaired_time) * failure_time) > rand
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
TRAFFIC_DEMAND = 10 #一秒当たりの平均トラフィック発生量
HOLDING_TIME = 5 #平均トラフィック保持時間
TOTAL_TRAFFIC = 100 #総トラフィック量
MAX_ROUTE = 3 #一つの要求に使用される最大ルート数
AVERAGE_REPAIRED_TIME = 5


traffic_list = []
traffic_count = 0
second = 0
blocked_bandwidth = 0
blocked_demand = 0
bandwidth_achived_demand = 0

begin
  traffic_per_second = random.poisson(TRAFFIC_DEMAND)
  traffic_list << []
  for num in 0...traffic_per_second
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

current_link_list = Marshal.load(Marshal.dump(link_list)) #使用可能なリンクリスト
active_traffic_list = []

time = 0
begin
  write_log(sprintf("\nSimulation Time: %d\n", time))
  # リンク障害判定
  current_link_list.each { |link_ary|
    link_ary.each { |link|
      if link != nil
        if link.failure_status == 0
          # リンク故障してないとき
          if is_failure(link.failure_rate)
            # リンク故障判定
            link.failure_status += 1
            write_log(sprintf("Link %d->%d failed\n", link.start_node, link.end_node))
            #   使用中リンクのダウン設定
            active_traffic_list.each { |active_traffic|
              del_route_list = []
              expected_bandwidth = active_traffic.traffic.bandwidth * active_traffic.traffic.quality #帯域幅期待値
              total_bandwidth = 0 #動作中リンクの合計帯域幅
              active_traffic.routes.each_with_index { |route, i|
                del_flag = false
                route.each { |link_item|
                  if link.start_node == link_item.start_node && link.end_node == link_item.end_node
                    active_traffic.routes[i].each { |failed_routes_link|
                      #  故障したリンクの存在するルートのすべてのリンクの使用を中断、使用帯域幅解放
                      current_link_list[failed_routes_link.start_node - 1][failed_routes_link.end_node - 1].bandwidth += active_traffic.traffic.bandwidth
                      write_log(sprintf("Link %d->%d add bandwidth: %d\n", failed_routes_link.start_node, failed_routes_link.end_node, failed_routes_link.bandwidth))
                    }
                    #削除リストに追加
                    del_route_list << i
                    del_flag = true
                    break
                  end
                }
                unless del_flag
                  total_bandwidth += route[0].bandwidth
                end
              }
              # アクティブトラフィックからルートを削除
              del_route_list.each { |del_route_index| active_traffic.routes.delete_at(del_route_index) }
              if total_bandwidth < expected_bandwidth
                write_log(sprintf("[Bandwidth Lowering(%d)] %d->%d (%d, %f)->%d\n", active_traffic.traffic.id, active_traffic.traffic.start_node, active_traffic.traffic.end_node, active_traffic.traffic.bandwidth, active_traffic.traffic.quality, total_bandwidth))
              end
            }
          end
        else
          # リンク故障しているとき
          if is_repaired(AVERAGE_REPAIRED_TIME, link.failure_status)
            # 復旧(使用帯域幅解放は実行済み)
            link.failure_status = 0
          else
            # 故障時間加算
            link.failure_status += 1
          end
        end
      end
    }
  }

  #回線使用終了判定
  end_list = active_traffic_list.map.with_index { |active_traffic, i|
    if active_traffic.end_time <= time
      #回線使用終了
      #使用帯域幅解放
      active_traffic.routes.each { |route|
        route.each { |used_link|
          current_link_list[used_link.start_node - 1][used_link.end_node - 1].bandwidth += used_link.bandwidth
          write_log(sprintf("Link %d->%d add bandwidth: %d\n", used_link.start_node, used_link.end_node, used_link.bandwidth))
        }
      }
      next i
    else
      next nil
    end
  }
  end_list.compact.each { |end_index| active_traffic_list.delete_at(end_index) }

  if traffic_list.size > 0
    traffic_list[0].each { |traffic_item|
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
      current_link_list.each { |ary|
        ary.each { |link|
          if link != nil && link.failure_status == 0
            distance_str << link.start_node.to_s << " " << link.end_node.to_s << " " << link.distance.to_s << "\n"
            bandwidth_str << link.start_node.to_s << " " << link.end_node.to_s << " " << link.bandwidth.to_s << "\n"
            reliability_str << link.start_node.to_s << " " << link.end_node.to_s << " " << exp(-1 * link.distance * link.failure_rate * traffic_item.holding_time).to_s << "\n"
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
      path = GLPK_PATH + (" -m routing.mod -o " << OUTPUT_FILE << " -d " << DATA_FILE)
      o, e, s = Open3.capture3(path)
      if o.match(/^INTEGER\sOPTIMAL\sSOLUTION\sFOUND$/) != nil
        #最適解発見
        out_file = File.open(OUTPUT_FILE)
        route=Array.new(MAX_ROUTE).map! { Array.new }
        out_file.each_line do |line|
          match = line.match(/\s+\d+ y\[(\d+),(\d+),(\d+)\]\s+\*\s+?(\d+)/)
          if match != nil
            if link_list[match[2].to_i - 1][match[3].to_i - 1] != nil
              if match[4].to_i > 0
                route[match[1].to_i - 1] << Link.new(match[2].to_i, match[3].to_i, link_list[match[2].to_i - 1][match[3].to_i - 1].distance, match[4].to_i, link_list[match[2].to_i - 1][match[3].to_i - 1].failure_rate, 0)
              end
            else
              write_log(sprintf("[Error] link %d->%d not found\n", match[2].to_i, match[3].to_i))
            end
          end
        end
=begin
      route.each_with_index { |route_item, i|
        if route_item != nil
          printf("Route %d ", i)
          route_item.each { |link|
            printf("(%d, %d, %d)", link.start_node, link.end_node, link.bandwidth)
          }
        end
        print "\n"
      }
=end
        write_log(sprintf("[Accepted(%d)] %d->%d (%d, %f)\n", traffic_item.id, traffic_item.start_node, traffic_item.end_node, traffic_item.bandwidth, traffic_item.quality))
        # ルート使用処理
        route_cnt = 0
        active_traffic = ActiveTraffic.new(time + traffic_item.holding_time, traffic_item.clone, [])
        route.each { |route_item|
          if route_item != nil && route_item.size > 0
            route_cnt = route_cnt.succ
            route_item.each { |link|
              current_link_list[link.start_node - 1][link.end_node - 1].bandwidth -= link.bandwidth #現在使用可能なリンクリストから帯域削除
              write_log(sprintf("Link %d->%d remove bandwidth: %d\n", link.start_node, link.end_node, link.bandwidth))
            }
            active_traffic.routes << route_item
          end
        }
        active_traffic_list << active_traffic
      else
        #最適解なし
        puts "Blocked"
        write_log(sprintf("[Blocked(%d)] %d->%d (%d, %f)\n", traffic_item.id, traffic_item.start_node, traffic_item.end_node, traffic_item.bandwidth, traffic_item.quality))
        blocked_bandwidth += traffic_item.bandwidth
        blocked_demand = blocked_demand.succ
      end
      # puts o
    }
  end
  time = time.succ
  # トラフィックリストから処理済みトラフィックを削除
  traffic_list.shift
end while traffic_list.size > 0 || active_traffic_list.size > 0


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
