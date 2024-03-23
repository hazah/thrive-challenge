require 'json'

# read in users.json file into the accompanying strcture
# interface User {
#   id: number;
#   first_name: string;
#   last_name: string;
#   email: string;
#   company_id: number;
#   email_status: boolean;
#   active_status: boolean;
#   tokens: number;
# }

# // example user data
# const user: User = {
#   id: 1,
#   first_name: "Tanya",
#   last_name: "Nichols",
#   email: "tanya.nichols@test.com",
#   company_id: 2,
#   email_status: true,
#   active_status: false,
#   tokens: 23
# };
User = Struct.new(:id, :first_name, :last_name, :email, :company_id,
                  :email_status, :active_status, :tokens, :tokens_after_top_up)

# read in companies.json file into the accompanying strcture
# interface Company {
#   id: number;
#   name: string;
#   top_up: number;
#   email_status: boolean;
# }
#
# // example company data
# const company: Company = {
#   id: 1,
#   name: "Company 1",
#   top_up: 10,
#   email_status: true
# };

Company = Struct.new(:id, :name, :top_up, :email_status, :users) do
  def users_emailed
    users.sort_by_last_name.select { |user| user.email_status && email_status }.each do |user|
      yield user
    end
  end

  def users_not_emailed
    users.sort_by_last_name.select { |user| !user.email_status || !email_status }.each do |user|
      yield user
    end
  end
end

class UsersError < StandardError
end

class UsersInputFileNotFoundError < UsersError
end

class UsersInvalidDataError < UsersError
end

class CompaniesError < StandardError
end

class CompaniesInputFileNotFoundError < CompaniesError
end

class CompaniesInvalidDataError < CompaniesError
end

class Users
  def initialize(users: [])
    @users = users.filter { |user| user.active_status }
  end

  def users
    sort_by_last_name
  end
  
  def read_file(file)
    begin
      data = File.read(file)
      
      @users = JSON.parse(data).map do |user|
        raise UsersInvalidDataError, "Invalid data for #{user.to_json}" unless
          !user['id'].nil? &&
          !user['first_name'].nil? &&
          !user['last_name'].nil? &&
          !user['email'].nil? &&
          !user['company_id'].nil? &&
          !user['email_status'].nil? &&
          !user['active_status'].nil? &&
          !user['tokens'].nil?
        
        User.new(
          user['id'], 
          user['first_name'], 
          user['last_name'], 
          user['email'], 
          user['company_id'], 
          user['email_status'], 
          user['active_status'], 
          user['tokens']) if user['active_status']
      end.compact
    rescue JSON::ParserError
      raise UsersInvalidDataError, 'Invalid JSON data for users.json file. Please make sure the file is valid and try again.'
    rescue Errno::ENOENT
      raise UsersInputFileNotFoundError, 'File users.json not found in current directory. ' +
        'Please make sure the file exists and try again.'
    end
  end

  def find_by_company(company)
    Users.new(users: users.select { |user| 
      user.company_id == company['id'] 
    }.map { |user| 
      user.tap { |u| 
        u.tokens_after_top_up = u.active_status ? u.tokens + company['top_up'] : u.tokens 
      }
    })
  end

  def sort_by_last_name
    @users.sort_by { |user| user.last_name }
  end

  def each
    users.each { |user| yield user }
  end
end

class Companies
  def initialize(users)
    @companies = []
    @users = users
  end

  def companies
    sort_by_id
  end

  def read_file(file)
    begin
      data = File.read(file)

      @companies = JSON.parse(data).map do |company|
        raise CompaniesInvalidDataError, "Invalid data for #{company.to_json}" unless
          !company['id'].nil? &&
          !company['name'].nil? &&
          !company['top_up'].nil? &&
          !company['email_status'].nil?

        users = @users.find_by_company(company)

        Company.new(
          company['id'], 
          company['name'], 
          company['top_up'], 
          company['email_status'],
          users) if users.users.length > 0
      end.compact
    rescue JSON::ParserError
      raise CompaniesInvalidDataError, 'Invalid JSON data for companies.json file. Please make sure the file is valid and try again.'
    rescue Errno::ENOENT
      raise CompaniesInputFileNotFoundError, 'File companies.json not found in current directory. ' +
        'Please make sure the file exists and try again.'
    end
  end

  def sort_by_id
    @companies.sort_by { |company| company.id }
  end

  def each
    companies.each { |company| yield company }
  end
end

# in general, the objects would load their dependencies as dictated by the context in which they are used,
# but for this example, we will load the users first and then the companies to ensure each company
# has the associated users it needs
users = Users.new
users.read_file('users.json')

companies = Companies.new(users)
companies.read_file('companies.json')

# output the results
def puts_user(user, sink)
  sink.puts "\t\t#{user.last_name}, #{user.first_name}, #{user.email}"
  sink.puts "\t\t  Previous token balance, #{user.tokens}"
  sink.puts "\t\t  New token balance #{user.tokens_after_top_up}"
end

def puts_company(company, sink)
  sink.puts "\tCompanyId: #{company.id}"
  sink.puts "\tCompany: #{company.name}"
  
  sink.puts "\tUsers Emailed:"
  company.users_emailed &(->(user) { puts_user(user, sink) })
  
  sink.puts "\tUsers Not Emailed:"
  company.users_not_emailed &(->(user) { puts_user(user, sink) })
  
  sink.puts "\t\tTotal amount of top ups for #{company.name}: #{company.top_up * company.users.users.length}"
end

def print_companies(companies, sink)
  sink.puts
  companies.each &(->(company) { puts_company(company, sink) })
  sink.puts
end

# output the results to the console
print_companies(companies, $stdout)

# output the results to output.txt file
File.open('output.txt', 'w') do |file|
  print_companies(companies, file)
end
