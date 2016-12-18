class Simulator
  # トポロジー読み込み
  topology = File.open('topology.txt')
  topology_array = Array.new
  node_list = Array.new
  i = 0
  topology.each_line do |topology_line|
    if i == 0
      node_list = topology_line.split.map(&:to_i)
    else
      if (match = topology_line.match(/(\d+)\s(\d+)/))!= nil
        topology_array.push([match[1], match[2]])
      end
    end
    i.succ
  end

  # 初期設定生成


  node_list.each do |item|
    puts item
  end
end