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

def write_log2(message)
  log_file = File.open(LOG_FILE2, "a")
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
DATA_FILE = "routing_test.dat"
OUTPUT_FILE = "routing_test.out"
LOG_FILE = "log.txt"
LOG_FILE2 = "log2.txt"

#トラフィック要求発生
TRAFFIC_DEMAND = 25 #一秒当たりの平均トラフィック発生量
HOLDING_TIME = 4 #平均トラフィック保持時間
TOTAL_TRAFFIC = 1000 #総トラフィック量
MAX_ROUTE = 3 #一つの要求に使用される最大ルート数
AVERAGE_REPAIRED_TIME = 5

# 条件復元
f = File.open('link_list.txt', 'rb')
link_list = Marshal.load(f)
f.close
f = File.open('traffic_list.txt', 'rb')
traffic_list = Marshal.load(f)
f.close

total_requested_bandwidth = 0
traffic_list.each { |traffic_list_sec|
  traffic_list_sec.each { |traffic_item|
    total_requested_bandwidth += traffic_item.bandwidth
  }
}
puts total_requested_bandwidth

active_traffic_list = []
active_traffic_list2 = []
current_link_list = Marshal.load(Marshal.dump(link_list))
current_link_list2 = Marshal.load(Marshal.dump(link_list))

node_size = current_link_list.size

time = 0
blocked_bandwidth = 0
blocked_demand = 0
bandwidth_achived_demand = 0
blocked_bandwidth2 = 0
blocked_demand2 = 0
bandwidth_achived_demand2 = 0

begin
  write_log(sprintf("\nSimulation Time: %d\n", time))
  write_log2(sprintf("\nSimulation Time: %d\n", time))
  # リンク障害判定
  current_link_list.each_with_index { |link_ary, i|
    link_ary.each_with_index { |link, j|
      if link != nil
        if link.failure_status == 0
          # リンク故障してないとき
          if is_failure(link.failure_rate)
            # リンク故障判定
            link.failure_status += 1
            write_log(sprintf("[Link failed] %d->%d\n", link.start_node, link.end_node))
            current_link_list2[i][j].failure_status += 1
            write_log2(sprintf("[Link failed] %d->%d\n", current_link_list2[i][j].start_node, current_link_list2[i][j].end_node))
            #   使用中リンクのダウン設定
            active_traffic_list.each { |active_traffic|
              expected_bandwidth = active_traffic.traffic.bandwidth * active_traffic.traffic.quality #帯域幅期待値
              total_bandwidth = 0 #動作中リンクの合計帯域幅
              active_traffic.routes.delete_if { |route|
                del_flag = false
                route.each { |link_item|
                  if link.start_node == link_item.start_node && link.end_node == link_item.end_node
                    route.each { |failed_routes_link|
                      #  故障したリンクの存在するルートのすべてのリンクの使用を中断、使用帯域幅解放
                      current_link_list[failed_routes_link.start_node - 1][failed_routes_link.end_node - 1].bandwidth += failed_routes_link.bandwidth
                      write_log(sprintf("Link %d->%d add bandwidth: %d\n", failed_routes_link.start_node, failed_routes_link.end_node, failed_routes_link.bandwidth))
                    }
                    #削除リストに追加
                    del_flag = true
                    break
                  end
                }
                if del_flag
                  next true
                else
                  total_bandwidth += route[0].bandwidth
                  next false
                end
              }
              if total_bandwidth < expected_bandwidth
                write_log(sprintf("[Bandwidth Lowering(%d)] %d->%d (%d, %f)->%d\n", active_traffic.traffic.id, active_traffic.traffic.start_node, active_traffic.traffic.end_node, active_traffic.traffic.bandwidth, active_traffic.traffic.quality, total_bandwidth))
              end
            }
            # 最小費用流アクティブトラフィック
            active_traffic_list2.each { |active_traffic|
              expected_bandwidth = active_traffic.traffic.bandwidth * active_traffic.traffic.quality #帯域幅期待値
              total_bandwidth = 0 #動作中リンクの合計帯域幅
              active_traffic.routes.delete_if { |route|
                del_flag = false
                route.each { |link_item|
                  if link.start_node == link_item.start_node && link.end_node == link_item.end_node
                    route.each { |failed_routes_link|
                      #  故障したリンクの存在するルートのすべてのリンクの使用を中断、使用帯域幅解放
                      current_link_list2[failed_routes_link.start_node - 1][failed_routes_link.end_node - 1].bandwidth += failed_routes_link.bandwidth
                      write_log2(sprintf("Link %d->%d add bandwidth: %d\n", failed_routes_link.start_node, failed_routes_link.end_node, failed_routes_link.bandwidth))
                    }
                    #削除リストに追加
                    del_flag = true
                    break
                  end
                }
                if del_flag
                  next true
                else
                  total_bandwidth += route[0].bandwidth
                  next false
                end
              }
              if total_bandwidth < expected_bandwidth
                write_log2(sprintf("[Bandwidth Lowering(%d)] %d->%d (%d, %f)->%d\n", active_traffic.traffic.id, active_traffic.traffic.start_node, active_traffic.traffic.end_node, active_traffic.traffic.bandwidth, active_traffic.traffic.quality, total_bandwidth))
              end
            }
          end
        else
          # リンク故障しているとき
          if is_repaired(AVERAGE_REPAIRED_TIME, link.failure_status)
            # 復旧(使用帯域幅解放は実行済み)
            write_log(sprintf("[Link repaired] %d->%d\n", link.start_node, link.end_node))
            link.failure_status = 0
            write_log2(sprintf("[Link repaired] %d->%d\n", current_link_list2[i][j].start_node, current_link_list2[i][j].end_node))
            current_link_list2[i][j].failure_status = 0
          else
            # 故障時間加算
            link.failure_status += 1
            current_link_list2[i][j].failure_status += 1
          end
        end
      end
    }
  }

  #回線使用終了判定
  active_traffic_list.delete_if { |active_traffic|
    if active_traffic.end_time <= time
      #回線使用終了
      write_log(sprintf("[End(%d)] %d->%d (%d, %f), %d\n", active_traffic.traffic.id, active_traffic.traffic.start_node, active_traffic.traffic.end_node, active_traffic.traffic.bandwidth, active_traffic.traffic.quality, active_traffic.end_time))
      #使用帯域幅解放
      expected_bandwidth = active_traffic.traffic.bandwidth * active_traffic.traffic.quality #帯域幅期待値
      total_bandwidth = 0 #動作中リンクの合計帯域幅
      active_traffic.routes.each { |route|
        route.each { |used_link|
          current_link_list[used_link.start_node - 1][used_link.end_node - 1].bandwidth += used_link.bandwidth
          total_bandwidth += used_link.bandwidth
          write_log(sprintf("Link %d->%d add bandwidth: %d\n", used_link.start_node, used_link.end_node, used_link.bandwidth))
        }
      }

      if total_bandwidth >= expected_bandwidth
        bandwidth_achived_demand += 1
      end
      next true
    else
      next false
    end
  }
  write_log(show_links(current_link_list))
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

  # 最小費用流

  #回線使用終了判定
  active_traffic_list2.delete_if { |active_traffic|
    if active_traffic.end_time <= time
      #回線使用終了
      write_log2(sprintf("[End(%d)] %d->%d (%d, %f), %d\n", active_traffic.traffic.id, active_traffic.traffic.start_node, active_traffic.traffic.end_node, active_traffic.traffic.bandwidth, active_traffic.traffic.quality, active_traffic.end_time))
      #使用帯域幅解放
      expected_bandwidth = active_traffic.traffic.bandwidth * active_traffic.traffic.quality #帯域幅期待値
      total_bandwidth = 0 #動作中リンクの合計帯域幅
      active_traffic.routes.each { |route|
        route.each { |used_link|
          current_link_list2[used_link.start_node - 1][used_link.end_node - 1].bandwidth += used_link.bandwidth
          total_bandwidth += used_link.bandwidth
          write_log2(sprintf("Link %d->%d add bandwidth: %d\n", used_link.start_node, used_link.end_node, used_link.bandwidth))
        }
      }

      if total_bandwidth >= expected_bandwidth
        bandwidth_achived_demand2 += 1
      end
      next true
    else
      next false
    end
  }
  write_log2(show_links(current_link_list2))
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
      # data_file.puts("param Q := " << 0.to_s << " ;")
      distance_str = ""
      bandwidth_str = ""
      # reliability_str = ""
      bandwidth_max = 0
      #リンク、距離定義
      current_link_list2.each { |ary|
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
      #GLPK実行
      path = GLPK_PATH + (" -m routing_mincostflow.mod -o " << OUTPUT_FILE << " -d " << DATA_FILE)
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
              write_log2(sprintf("[Error] link %d->%d not found\n", match[2].to_i, match[3].to_i))
            end
          end
        end
        write_log2(sprintf("[Accepted(%d)] %d->%d (%d, %f)\n", traffic_item.id, traffic_item.start_node, traffic_item.end_node, traffic_item.bandwidth, traffic_item.quality))
        # ルート使用処理
        route_cnt = 0
        active_traffic = ActiveTraffic.new(time + traffic_item.holding_time, traffic_item.clone, [])
        route.each { |route_item|
          if route_item != nil && route_item.size > 0
            route_cnt = route_cnt.succ
            route_item.each { |link|
              current_link_list2[link.start_node - 1][link.end_node - 1].bandwidth -= link.bandwidth #現在使用可能なリンクリストから帯域削除
              write_log2(sprintf("Link %d->%d remove bandwidth: %d\n", link.start_node, link.end_node, link.bandwidth))
            }
            active_traffic.routes << route_item
          end
        }
        active_traffic_list2 << active_traffic
      else
        #最適解なし
        puts "Blocked"
        write_log2(sprintf("[Blocked(%d)] %d->%d (%d, %f)\n", traffic_item.id, traffic_item.start_node, traffic_item.end_node, traffic_item.bandwidth, traffic_item.quality))
        blocked_bandwidth2 += traffic_item.bandwidth
        blocked_demand2 = blocked_demand2.succ
      end
      # puts o
    }
  end

  time = time.succ
  # トラフィックリストから処理済みトラフィックを削除
  traffic_list.shift
end while traffic_list.size > 0 || active_traffic_list.size > 0
write_log(sprintf("Blocked demand:%d(%d%%)\nTotal bandwidth: %d\nBlocked bandwidth: %d\nBandwidth achieved demand: %d(%d%%)\n", blocked_demand, blocked_demand*100/TOTAL_TRAFFIC, total_requested_bandwidth, blocked_bandwidth, bandwidth_achived_demand, bandwidth_achived_demand*100/TOTAL_TRAFFIC))
write_log2(sprintf("Blocked demand:%d(%d%%)\nTotal bandwidth: %d\nBlocked bandwidth: %d\nBandwidth achieved demand: %d(%d%%)\n", blocked_demand2, blocked_demand2*100/TOTAL_TRAFFIC, total_requested_bandwidth, blocked_bandwidth2, bandwidth_achived_demand2, bandwidth_achived_demand2*100/TOTAL_TRAFFIC))

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
