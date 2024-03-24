require 'json'

# The following sections would normally reside in a separate files, but for the sake of this example
# they are inlined here. The code defines the structures for the User and Company objects
# and the Users and Companies classes. The User and Company objects are defined as Structs, which
# are used to store the data for each user and company respectively. The Users and Companies classes
# are used to manage the collections of users and companies respectively. The Users class includes
# methods to read in the users.json file, filter out inactive users, find users by company, sort users
# by last name, and filter the users. The Companies class includes methods to read in the companies.json
# file, sort companies by id, filter out companies without users, and iterate over the companies. The
# code also includes error classes for handling file not found and invalid data errors for the users and
# companies files.

# Utility functions are included for reading in the data from the JSON files, validating the data,
# filtering the data, and creating instances of the User and Company objects. The utility functions are used
# by the Users and Companies classes to read in the data from the JSON files and create the instances of the User
# and Company objects. The utility functions also handle errors such as file not found and invalid data errors.

# Output functions are included for printing the users and companies to any output stream. The output
# functions iterate over the users and companies and print the data to the stream in a
# human-readable format.

# The main section reads in the users and companies data from the users.json and companies.json
# files, creates the Users and Companies objects, and outputs the results to output.txt as well as the console.

# The program is written in Ruby and can be run from the command line using the following command:
# ruby challenge.rb

# The users.json and companies.json files are read from the current directory, so make sure to place
# the files in the same directory as the challenge.rb file.

# domain specific errors
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

# domain specific data structures/models annotated with TypeScript-like interfaces

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

# domain specific data structures/models

User = Struct.new(:id, :first_name, :last_name, :email, :company_id,
                  :email_status, :active_status, :tokens, :tokens_after_top_up)

Company = Struct.new(:id, :name, :top_up, :email_status, :users) do
  def users_emailed
    users.select { |user| user.email_status && email_status }.each do |user|
      yield user
    end
  end

  def users_not_emailed
    users.select { |user| !user.email_status || !email_status }.each do |user|
      yield user
    end
  end
end

# domain specific collections

class Users
  def initialize(users: [])
    @users = users.filter { |user| user.active_status }
  end

  def users
    sort_by_last_name
  end
  
  def read_file(filename)
    validation = Proc.new do |user|
      required_fields = ['id', 'first_name', 'last_name', 'email', 'company_id', 'email_status', 'active_status', 'tokens']
      missing_keys = required_fields.reject { |field| user.key?(field) }
      raise UsersInvalidDataError, "Missing required fields: #{missing_keys.join(', ')}" unless missing_keys.empty?
    end

    filters = Proc.new do |user|
      user['active_status']
    end

    @users = init_collection(User, UsersInvalidDataError, UsersInputFileNotFoundError, filename, validation, filters)
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

  def select
    users.select { |user| yield user }
  end

  def length
    users.length
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

  def read_file(filename)
    validation = Proc.new do |company|
      required_fields = ['id', 'name', 'top_up', 'email_status']
      missing_keys = required_fields.reject { |field| company.key?(field) }
      raise CompaniesInvalidDataError, "Missing required fields: #{missing_keys.join(', ')}" unless missing_keys.empty?
    end

    filters = Proc.new do |company|
      @users.find_by_company(company).length > 0
    end

    extra = Proc.new do |company|
      users = @users.find_by_company(company)
      company.merge(users: users)
    end

    @companies = init_collection(Company, CompaniesInvalidDataError, CompaniesInputFileNotFoundError, filename, validation, filters, extra)
  end

  def sort_by_id
    @companies.sort_by { |company| company.id }
  end

  def each
    companies.each { |company| yield company }
  end
end

# utility functions

# This function reads the data from a file, parses it as JSON
# and then maps the data to instances of the given class. It validates the data using the
# given validation function and filters the data using the given filters function. The extra
# function can be used to add additional data to the item before creating the instance of the class.
# The function returns an array of instances of the given class expected by its corresponding collection.
#
# @param klass [Class] The class to instantiate for each item in the collection.
# @param invalid_data_error_klass [Class] The error class to raise if the JSON data is invalid.
# @param file_not_found_error_klass [Class] The error class to raise if the file is not found.
# @param filename [String] The name of the JSON file to read.
# @param validation [Proc] A function to validate each item in the collection.
# @param filters [Proc] A function to filter each item in the collection.
# @param extra [Proc] An optional function to apply to each item in the collection. Defaults to a function that returns the item unchanged.
# @return [Array] An array of instances of the given class.
def init_collection(klass, invalid_data_error_klass, file_not_found_error_klass, filename, validation, filters, extra = ->(item) { item })
  begin
    data = File.read(filename)
    JSON.parse(data).map do |item|
      validation.call(item)
      
      item_with_extra = extra.call(item)
      klass.new(**item_with_extra) if filters.call(item_with_extra)
    end.compact
  rescue JSON::ParserError
    raise invalid_data_error_klass, "Invalid JSON data for #{filename} file. Please make sure the file is valid and try again."
  rescue Errno::ENOENT
    raise file_not_found_error_klass, "File #{filename} not found in current directory. Please make sure the file exists and try again."
  end
end

# output functions assume the sink is a stream that responds to puts (e.g. $stdout, file, etc.)
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

# in general, the objects would load their dependencies as dictated by the context and framework in which they are used,
# but for this example, we will hardcoad loading the users first and then the companies to ensure each company
# has the associated users it needs

puts 'Reading users...'
users = Users.new
users.read_file('users.json')
puts 'users read successfully!'

puts 'Reading companies...'
companies = Companies.new(users)
companies.read_file('companies.json')
puts 'companies read successfully!'

# output the results to the console
print_companies(companies, $stdout)

# output the results to output.txt file
puts 'Writing output to output.txt...'
begin
  File.open('output.txt', 'w') do |file|
    print_companies(companies, file)
  end
rescue Errno::ENOENT
  puts 'Error writing output to output.txt. Please make sure the file is not open and try again.'
end
puts 'output written successfully!'
