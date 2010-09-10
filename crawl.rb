require 'hsbc'

config = load_config
output = crawl(config)
output = remove_duplicates(output)

File.open('output.csv', 'w') do |f|
  output.each {|row| f.write row}
end
