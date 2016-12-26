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

def write_log3(message)
  log_file = File.open(LOG_FILE3, "a")
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


# 構造体宣言
Link = Struct.new(:start_node, :end_node, :distance, :bandwidth, :failure_rate, :failure_status)
Traffic = Struct.new(:id, :holding_time, :bandwidth, :quality, :start_node, :end_node)
ActiveTraffic = Struct.new(:end_time, :traffic, :routes)
Define = Struct.new(:traffic_demand, :holding_time, :total_traffic, :max_route, :average_repaired_time)

# GLPK_PATH = "C:\\Users\\shugonta\\Documents\\gusek\\glpsol.exe"
GLPK_PATH = "glpsol"
DATA_FILE = "routing_test.dat"
OUTPUT_FILE = "routing_test.out"
LOG_FILE = "log.txt"
LOG_FILE2 = "log2.txt"
LOG_FILE3 = "log3.txt"
RESULT_FILE = "result.txt"
CPLEX_PATH = "cplex"
CPLEX_LP = "cplex.lp"
CPLEX_SCRIPT = "cplex.txt"

#トラフィック要求発生

# 条件復元
f = File.open('link_list.txt', 'rb')
link_list = Marshal.load(f)
f.close
f = File.open('traffic_list.txt', 'rb')
traffic_list = Marshal.load(f)
f.close
f = File.open('define.txt', 'rb')
define = Marshal.load(f)
f.close

TOTAL_TRAFFIC = define.total_traffic #総トラフィック量
MAX_ROUTE = define.max_route #一つの要求に使用される最大ルート数
AVERAGE_REPAIRED_TIME = define.average_repaired_time


total_requested_bandwidth = 0
traffic_list.each { |traffic_list_sec|
  traffic_list_sec.each { |traffic_item|
    total_requested_bandwidth += traffic_item.bandwidth
  }
}
puts total_requested_bandwidth

active_traffic_list = []
active_traffic_list2 = []
active_traffic_list3 = []
current_link_list = Marshal.load(Marshal.dump(link_list))
current_link_list2 = Marshal.load(Marshal.dump(link_list))
current_link_list3 = Marshal.load(Marshal.dump(link_list))

node_size = current_link_list.size

time = 0
blocked_bandwidth = 0
blocked_demand = 0
request_achived_demand = 0
blocked_bandwidth2 = 0
blocked_demand2 = 0
request_achived_demand2 = 0
blocked_bandwidth3 = 0
blocked_demand3 = 0
request_achived_demand3 = 0

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
            current_link_list3[i][j].failure_status += 1
            write_log3(sprintf("[Link failed] %d->%d\n", current_link_list3[i][j].start_node, current_link_list3[i][j].end_node))
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

            # バックアップ経路アクティブトラフィック
            active_traffic_list3.each { |active_traffic|
              expected_bandwidth = active_traffic.traffic.bandwidth * active_traffic.traffic.quality #帯域幅期待値
              total_bandwidth = 0 #動作中リンクの合計帯域幅
              active_traffic.routes.delete_if { |route|
                del_flag = false
                route.each { |link_item|
                  if link.start_node == link_item.start_node && link.end_node == link_item.end_node
                    route.each { |failed_routes_link|
                      #  故障したリンクの存在するルートのすべてのリンクの使用を中断、使用帯域幅解放
                      current_link_list3[failed_routes_link.start_node - 1][failed_routes_link.end_node - 1].bandwidth += failed_routes_link.bandwidth
                      write_log3(sprintf("Link %d->%d add bandwidth: %d\n", failed_routes_link.start_node, failed_routes_link.end_node, failed_routes_link.bandwidth))
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
                write_log3(sprintf("[Bandwidth Lowering(%d)] %d->%d (%d, %f)->%d\n", active_traffic.traffic.id, active_traffic.traffic.start_node, active_traffic.traffic.end_node, active_traffic.traffic.bandwidth, active_traffic.traffic.quality, total_bandwidth))
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
            write_log3(sprintf("[Link repaired] %d->%d\n", current_link_list3[i][j].start_node, current_link_list3[i][j].end_node))
            current_link_list3[i][j].failure_status = 0
          else
            # 故障時間加算
            link.failure_status += 1
            current_link_list2[i][j].failure_status += 1
            current_link_list3[i][j].failure_status += 1
          end
        end
      end
    }
  }

  #回線使用終了判定
  active_traffic_list.delete_if { |active_traffic|
    if active_traffic.end_time <= time
      #回線使用終了
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
        request_achived_demand += 1
        write_log(sprintf("[End(%d)] %d->%d (%d, %f), %d\n", active_traffic.traffic.id, active_traffic.traffic.start_node, active_traffic.traffic.end_node, active_traffic.traffic.bandwidth, active_traffic.traffic.quality, active_traffic.end_time))
      else
        write_log(sprintf("[End with Bandwidth Lowering(%d)] %d->%d (%d, %f)->%d, %d\n", active_traffic.traffic.id, active_traffic.traffic.start_node, active_traffic.traffic.end_node, active_traffic.traffic.bandwidth, active_traffic.traffic.quality, total_bandwidth, active_traffic.end_time))
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
      glpk_path = GLPK_PATH + (" -m routing.mod -o " << OUTPUT_FILE << " -d " << DATA_FILE << " --wlpt " << CPLEX_LP << " --check")
      o, e, s = Open3.capture3(glpk_path)
      if o.match(/^Model has been successfully generated$/) != nil
        cplex_path = CPLEX_PATH + (" < " << CPLEX_SCRIPT)
        o2, e2, s2 = Open3.capture3(cplex_path)
        if o2.match(/Integer optimal solution/) != nil
          #最適解発見
          route=Array.new(MAX_ROUTE).map! { Array.new }
          o2.scan(/^y\((\d+),(\d+),(\d+)\)\s+(\d+\.\d+)/) do |route_num, start_node, end_node, cost|
            if link_list[start_node.to_i - 1][end_node.to_i - 1] != nil
              if cost.to_i > 0
                route[route_num.to_i - 1] << Link.new(start_node.to_i, end_node.to_i, link_list[start_node.to_i - 1][end_node.to_i - 1].distance, cost.to_i, link_list[start_node.to_i - 1][end_node.to_i - 1].failure_rate, 0)
              end
            else
              write_log(sprintf("[Error] link %d->%d not found\n", start_node.to_i, end_node.to_i))
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
          write_log(show_links_wR(current_link_list, traffic_item))
          write_log(sprintf("[Blocked(%d)] %d->%d (%d, %f)\n", traffic_item.id, traffic_item.start_node, traffic_item.end_node, traffic_item.bandwidth, traffic_item.quality))
          blocked_bandwidth += traffic_item.bandwidth
          blocked_demand = blocked_demand.succ
          # exit
        end
      else
        #   モデル異常
        puts 'Model Error'
        puts o
        exit
      end
      # puts o
    }
  end

  # 最小費用流

  #回線使用終了判定
  active_traffic_list2.delete_if { |active_traffic|
    if active_traffic.end_time <= time
      #回線使用終了
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
        request_achived_demand2 += 1
        write_log2(sprintf("[End(%d)] %d->%d (%d, %f), %d\n", active_traffic.traffic.id, active_traffic.traffic.start_node, active_traffic.traffic.end_node, active_traffic.traffic.bandwidth, active_traffic.traffic.quality, active_traffic.end_time))
      else
        write_log2(sprintf("[End with Bandwidth Lowering(%d)] %d->%d (%d, %f)->%d, %d\n", active_traffic.traffic.id, active_traffic.traffic.start_node, active_traffic.traffic.end_node, active_traffic.traffic.bandwidth, active_traffic.traffic.quality, total_bandwidth, active_traffic.end_time))
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
      glpk_path = GLPK_PATH + (" -m routing_mincostflow.mod -o " << OUTPUT_FILE << " -d " << DATA_FILE << " --wlpt " << CPLEX_LP << " --check")
      o, e, s = Open3.capture3(glpk_path)
      if o.match(/^Model has been successfully generated$/) != nil
        cplex_path = CPLEX_PATH + (" < " << CPLEX_SCRIPT)
        o2, e2, s2 = Open3.capture3(cplex_path)
        if o2.match(/Integer optimal solution/) != nil
          #最適解発見
          route=Array.new(MAX_ROUTE).map! { Array.new }
          o2.scan(/^y\((\d+),(\d+),(\d+)\)\s+(\d+\.\d+)/) do |route_num, start_node, end_node, cost|
            if link_list[start_node.to_i - 1][end_node.to_i - 1] != nil
              if cost.to_i > 0
                route[route_num.to_i - 1] << Link.new(start_node.to_i, end_node.to_i, link_list[start_node.to_i - 1][end_node.to_i - 1].distance, cost.to_i, link_list[start_node.to_i - 1][end_node.to_i - 1].failure_rate, 0)
              end
            else
              write_log2(sprintf("[Error] link %d->%d not found\n", start_node.to_i, end_node.to_i))
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
      else
        #   モデル異常
        puts 'Model Error'
        puts o
        exit
      end
      # puts o
    }
  end

  #バックアップ経路

  #回線使用終了判定
  active_traffic_list3.delete_if { |active_traffic|
    if active_traffic.end_time <= time
      #回線使用終了
      #使用帯域幅解放
      expected_bandwidth = active_traffic.traffic.bandwidth * active_traffic.traffic.quality #帯域幅期待値
      total_bandwidth = 0 #動作中リンクの合計帯域幅
      active_traffic.routes.each { |route|
        route.each { |used_link|
          current_link_list3[used_link.start_node - 1][used_link.end_node - 1].bandwidth += used_link.bandwidth
          total_bandwidth += used_link.bandwidth
          write_log3(sprintf("Link %d->%d add bandwidth: %d\n", used_link.start_node, used_link.end_node, used_link.bandwidth))
        }
      }

      if total_bandwidth >= expected_bandwidth
        request_achived_demand3 += 1
        write_log3(sprintf("[End(%d)] %d->%d (%d, %f), %d\n", active_traffic.traffic.id, active_traffic.traffic.start_node, active_traffic.traffic.end_node, active_traffic.traffic.bandwidth, active_traffic.traffic.quality, active_traffic.end_time))
      else
        write_log3(sprintf("[End with Bandwidth Lowering(%d)] %d->%d (%d, %f)->%d, %d\n", active_traffic.traffic.id, active_traffic.traffic.start_node, active_traffic.traffic.end_node, active_traffic.traffic.bandwidth, active_traffic.traffic.quality, total_bandwidth, active_traffic.end_time))
      end
      next true
    else
      next false
    end
  }
  write_log3(show_links(current_link_list3))
  if traffic_list.size > 0
    traffic_list[0].each { |traffic_item|
      #GLPK用データファイル作成
      #GLPK変数定義
      data_file = File.open(DATA_FILE, "w")
      data_file.puts("param N := " << node_size.to_s << " ;")
      data_file.puts("param M := " << 2.to_s << " ;")
      # data_file.puts("param M := " << MAX_ROUTE.to_s << " ;")
      data_file.puts("param p := " << traffic_item.start_node.to_s << " ;")
      data_file.puts("param q := " << traffic_item.end_node.to_s << " ;")
      data_file.puts("param B := " << traffic_item.bandwidth.to_s << " ;")
      data_file.puts("param Q := " << traffic_item.quality.to_s.to_s << " ;")
      distance_str = ""
      bandwidth_str = ""
      # reliability_str = ""
      bandwidth_max = 0
      #リンク、距離定義
      current_link_list3.each { |ary|
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
      glpk_path = GLPK_PATH + (" -m routing_backup.mod -o " << OUTPUT_FILE << " -d " << DATA_FILE << " --wlpt " << CPLEX_LP << " --check")
      o, e, s = Open3.capture3(glpk_path)
      if o.match(/^Model has been successfully generated$/) != nil
        cplex_path = CPLEX_PATH + (" < " << CPLEX_SCRIPT)
        o2, e2, s2 = Open3.capture3(cplex_path)
        # write_log3(o2 + "\n")
        if o2.match(/Integer optimal solution/) != nil
          #最適解発見
          route=Array.new(MAX_ROUTE).map! { Array.new }
          o2.scan(/^y\((\d+),(\d+),(\d+)\)\s+(\d+\.\d+)/) do |route_num, start_node, end_node, cost|
            if link_list[start_node.to_i - 1][end_node.to_i - 1] != nil
              if cost.to_i > 0
                route[route_num.to_i - 1] << Link.new(start_node.to_i, end_node.to_i, link_list[start_node.to_i - 1][end_node.to_i - 1].distance, cost.to_i, link_list[start_node.to_i - 1][end_node.to_i - 1].failure_rate, 0)
              end
            else
              write_log3(sprintf("[Error] link %d->%d not found\n", start_node.to_i, end_node.to_i))
            end
          end
          write_log3(sprintf("[Accepted(%d)] %d->%d (%d, %f)\n", traffic_item.id, traffic_item.start_node, traffic_item.end_node, traffic_item.bandwidth, traffic_item.quality))
          # ルート使用処理
          route_cnt = 0
          active_traffic = ActiveTraffic.new(time + traffic_item.holding_time, traffic_item.clone, [])
          route.each { |route_item|
            if route_item != nil && route_item.size > 0
              route_cnt = route_cnt.succ
              route_item.each { |link|
                current_link_list3[link.start_node - 1][link.end_node - 1].bandwidth -= link.bandwidth #現在使用可能なリンクリストから帯域削除
                write_log3(sprintf("Link %d->%d remove bandwidth: %d\n", link.start_node, link.end_node, link.bandwidth))
              }
              active_traffic.routes << route_item
            end
          }
          active_traffic_list3 << active_traffic
        else
          #最適解なし
          puts "Blocked"
          write_log3(sprintf("[Blocked(%d)] %d->%d (%d, %f)\n", traffic_item.id, traffic_item.start_node, traffic_item.end_node, traffic_item.bandwidth, traffic_item.quality))
          blocked_bandwidth3 += traffic_item.bandwidth
          blocked_demand3 = blocked_demand3.succ
        end
      else
        #   モデル異常
        puts 'Model Error'
        puts o
        exit
      end
      # puts o
    }
  end


  time = time.succ
  # トラフィックリストから処理済みトラフィックを削除
  traffic_list.shift
end while traffic_list.size > 0 || active_traffic_list.size > 0

# シミュレーション終了
write_log(sprintf("Blocked demand:%d(%d%%)\nTotal bandwidth: %d\nBlocked bandwidth: %d\nBandwidth achieved demand: %d(%d%%)\n", blocked_demand, blocked_demand*100/TOTAL_TRAFFIC, total_requested_bandwidth, blocked_bandwidth, request_achived_demand, request_achived_demand*100/(TOTAL_TRAFFIC-blocked_demand)))
write_log2(sprintf("Blocked demand:%d(%d%%)\nTotal bandwidth: %d\nBlocked bandwidth: %d\nBandwidth achieved demand: %d(%d%%)\n", blocked_demand2, blocked_demand2*100/TOTAL_TRAFFIC, total_requested_bandwidth, blocked_bandwidth2, request_achived_demand2, request_achived_demand2*100/(TOTAL_TRAFFIC-blocked_demand2)))
write_log2(sprintf("Blocked demand:%d(%d%%)\nTotal bandwidth: %d\nBlocked bandwidth: %d\nBandwidth achieved demand: %d(%d%%)\n", blocked_demand3, blocked_demand3*100/TOTAL_TRAFFIC, total_requested_bandwidth, blocked_bandwidth3, request_achived_demand3, request_achived_demand3*100/(TOTAL_TRAFFIC-blocked_demand3)))
result_file = File.open(RESULT_FILE, "a")
result_file.print("\n")
result_file.print(sprintf("Condition: Traffic demand: %d, Holding time: %d, Total traffic: %d, Max route: %d, Avg repair time: %d\n", define.traffic_demand, define.holding_time, define.total_traffic, define.max_route, define.average_repaired_time))
result_file.print("Propose\n")
result_file.print(sprintf("Blocked demand:%d(%d%%)\nTotal bandwidth: %d\nBlocked bandwidth: %d\nBandwidth achieved demand: %d(%d%%)\n", blocked_demand, blocked_demand*100/TOTAL_TRAFFIC, total_requested_bandwidth, blocked_bandwidth, request_achived_demand, request_achived_demand*100/(TOTAL_TRAFFIC-blocked_demand)))
result_file.print("minCostFlow\n")
result_file.print(sprintf("Blocked demand:%d(%d%%)\nTotal bandwidth: %d\nBlocked bandwidth: %d\nBandwidth achieved demand: %d(%d%%)\n", blocked_demand2, blocked_demand2*100/TOTAL_TRAFFIC, total_requested_bandwidth, blocked_bandwidth2, request_achived_demand2, request_achived_demand2*100/(TOTAL_TRAFFIC-blocked_demand2)))
result_file.print("Backup\n")
result_file.print(sprintf("Blocked demand:%d(%d%%)\nTotal bandwidth: %d\nBlocked bandwidth: %d\nBandwidth achieved demand: %d(%d%%)\n", blocked_demand3, blocked_demand3*100/TOTAL_TRAFFIC, total_requested_bandwidth, blocked_bandwidth3, request_achived_demand3, request_achived_demand3*100/(TOTAL_TRAFFIC-blocked_demand3)))
result_file.print("\n")
result_file.close
