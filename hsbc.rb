require 'rubygems'
require 'mechanize'
require 'open-uri'
require 'yaml'
require 'set'

POSITIONS = {
  'FIRST' => 0,
  'SECOND' => 1,
  'THIRD' => 2,
  'FOURTH' => 3,
  'FIFTH' => 4,
  'SIXTH' => 5,
  'SEVENTH' => 6,
  'EIGHTH' => 7,
  'NEXT TO LAST' => -2,
  'LAST' => -1,
}

def include_any?(str, arr)
  arr.each do |item|
    if str.include? item
      return true
    end
  end
  return false
end

def process_statement_page(page, output, options={})
  page.search('//table[@summary="This table contains a statement of your account"]').each do |table|
    puts 'processing transaction table...'
    puts "#{table.children.find {|c| c.name == 'tbody'}.children.length} rows"
    table.children.find {|c| c.name == 'tbody'}.children.each do |row|
      row_str = []
      row.children.each do |c|
        text = c.text.strip
        text.gsub!("\n", '')
        text.gsub!('\302\240\302\240', '')
        text.gsub!(/\s+/, ' ')
        text.gsub!(',', '-')
        text.strip!
        row_str << text
      end
      date = row_str[0]
      if date.length == 0
        next
      end
      if options.has_key? :year
        date = "#{date} #{options[:year]}"
      end
      output << "#{date},#{row_str[2]},#{row_str[4]},#{row_str[6]},#{row_str[8]},#{row_str[10]}\n"
    end
  end
end

##############

config = YAML.load_file('hsbc.yml') rescue {}
unless config.has_key? 'user_id'
  puts 'online banking user ID:'
  config['user_id'] = gets.chomp
end

unless config.has_key? 'date_of_birth'
  puts 'DoB (ddmmyy):'
  config['date_of_birth'] = gets.chomp
end

unless config.has_key? 'security_number'
  puts 'security number:'
  config['security_number'] = gets.chomp
end

unless config.has_key? 'account_number'
  puts 'Acc No:'
  config['account_number'] = gets.chomp
end

config.each_pair do |k, v|
  config[k] = v.to_s
end

##############

output = []

agent = Mechanize.new
# homepage
puts 'Homepage...'
page = agent.get('http://www.hsbc.co.uk')
page = page.link_with(:text => 'Log on to Personal Internet Banking').click
# login
puts 'Log in...'
form = page.forms[1]
form.userid = config['user_id']
page = agent.submit(form, form.buttons.first)
processed_security_number = ''
# security
puts 'Security...'
page.search('//div[@class="logonPageAlignment"]//span[@class="hsbcTextHighlight"]//strong').each do |s|
  unless s.content == 'date of birth'
    pos = s.content.strip
    processed_security_number << config['security_number'][POSITIONS[pos]]
  end
end
form = page.forms[2]
form.memorableAnswer = config['date_of_birth']
form.password = processed_security_number
page = agent.submit(form)
# Javascript disabled page
puts 'Javascript disabled page...'
page = page.links.find {|l| l.text.include? 'here'}.click
# Account selection
puts 'Account selection...'
page.forms.each do |form|
  form.buttons.each do |button|
    if button.name.include? config['account_number']
      unless include_any?(button.name, ['Make a payment', 'Transfer money', 'Activate card'])
        page = agent.submit(form, button)
        break
      end
    end
  end
end
# Recent transactions
puts 'Recent Transactions...'

begin
  process_statement_page(page, output)
  form = page.forms[1]
  if form.field_with(:name => 'fromDateDay').value != ''
    page = agent.submit(form, form.buttons.first)
  end
end while form.field_with(:name => 'fromDateDay').value != ''

page = page.links.find {|l| l.text.include? 'Previous statements'}.click

#previous statements
puts 'Previous statements...'

begin
  page.search('//table[@class="hsbcRowSeparator"]/tbody').each do |table|
    table.children.each do |row|
      link = row.children[0].children[1]
      year = row.children[2].text.strip
      puts link.text.strip, year
      statement_page = agent.click(link)
      begin
        process_statement_page(statement_page, output, :year => year)
        next_link = statement_page.links.find {|l| l.text.include? 'Next page'}
        if next_link
          statement_page = next_link.click
        end
      end while next_link
    end
  end

  next_link = page.links.find {|l| l.text.include? 'Next set'}
  if next_link
    page = next_link.click
  end
end while next_link

puts 'Removing duplicates...'
accepted = Set.new
File.open('output.csv', 'w') do |file|
  output.each do |row|
    unless accepted.include? row
      file.write row
      accepted.add row
    end
  end
end
puts 'Export completed.'

