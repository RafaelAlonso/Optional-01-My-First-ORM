# You can use a global variable, DB, which
# is an instance of SQLite3::Database
# NO NEED TO CREATE IT, JUST USE IT.

class Record
  def initialize(args = {})
    # Imagine we initialize a post or a user, passing a hash
    # Kinda like:
    #     - Post.new(id: 1, url: 'lewagon.com', title: 'Lewagon')
    #     - Post.new(title: 'Lewagon' url: 'lewagon.org')
    #     - User.new(id: 3, name: 'Rafa', age: 22)
    #     - User.new(name: 'Rafa')
    # Our job here is to create an instance variable for each of
    # these 'key-value' pairs, in such a way that we don't mind what
    # is going to be passed. Following the same order of the examples, we
    # should have something like:
    #     - @id = 1, @url = 'lewagon.com', @title = 'Lewagon'
    #     - @title = 'Lewagon', @url = 'lewagon.org'
    #     - @id = 3, @name = 'Rafa', @age = 22
    #     - @name = Rafa
    # Notice also that we do not need to create all instance variables
    # (like creating an @url = nil for a Post if nothing is passed). All
    # we need here is to create the variables with what we have.

    # For each 'key-value' pair that is passed to us as an argument
    # (Let's use the hash {id: 1, url: 'lewagon.com', title: 'Lewagon'} as
    # an example)...
    args.each do |key, value|
      # ...we need to create a new instance variable with a dynamic name (since
      # we don't know what 'key-value' pairs are gonna be passed to us).
      # The method #instance_variable_set allow us to do so by passing two params:
      #   - The name of the variable we'd like to create
      #   - The value of such variable
      # Since the name is dynamic depending on the *KEY* of the 'key-value' pair,
      # we can simply interpolate it with the '@' to get the name we want. The
      # value of this variable will then be the *VALUE* of the 'key-value' pair.
      instance_variable_set("@#{key}", value)
      # So, following the example, each iteration will result in:
      #   - (key = 'id', value = 1)              ==> @id = 1
      #   - (key = 'url', value = 'lewagon.org') ==> @url = 'lewagon.org'
      #   - (key = 'title', value = 'Lewagon')   ==> @title = 'Lewagon'

      # We also need to create an accessor to each of them. However, we cannot
      # simply write something like:
      #     attr_accessor key
      #     attr_accessor key.to_sym
      # The code will break (feel free to try it). We need a special way to call
      # this method inside this iterator (so we can have dynamic accessors).
      # That's where #send kicks in. It's a method (so we need to call it
      # with self.class.send) that try to execute another method (passed as the
      # first parameter) with some arguments (passed as the second parameter).
      # I'm not going to cover the details of how this works, but you can search
      # for more info in the documentation. Also, this stack overflow answer
      # gives a really nice example:
      #   https://stackoverflow.com/questions/3337285/what-does-send-do-in-ruby
      self.class.send('attr_accessor', key.to_sym)
    end
  end

  def destroy
    # To get the table name in a dynamic way (only for this exercise), all we
    # need to do is take the class name in lowercase and add an 's' to it

    # To delete a record, we need the id. Since we know all our instances are going
    # to have an id if someone tries to destroy it (only for this exercise), we
    # can call @id directly, without having to do any dynamic programming
    DB.execute("DELETE FROM #{self.class.name.downcase}s WHERE id = ?", @id)
  end

  def self.find(id)
    # We need the results as a hash if we want our initialize method to work
    DB.results_as_hash = true

    # To get the table name in a dynamic way (only for this exercise), all we
    # need to do is take the class name in lowercase and add an 's' to it
    query = "SELECT * FROM #{self.name.downcase}s WHERE id = ?"

    # The id is passed to us as an argument, so we don't need to be worried here
    result = DB.execute(query, id)

    # 'self' inside a class method == the class itself. For instance:
    #   Post.find(1) ==> self.new == Post.new
    #   User.find(4) ==> self.new == User.new
    # Since the result will always be an array, either empty ([]) when not finding
    # the record with the passed id or with a single hash ([{...}]) if something
    # was found, we try to create a new object with the hash (result[0]) unless
    # the array itself is empty, in which case we simply return nil
    self.new(result[0]) unless result.empty?
  end

  def self.all
    # We need the results as a hash if we want our initialize method to work
    DB.results_as_hash = true

    # To get the table name in a dynamic way (only for this exercise), all we
    # need to do is take the class name in lowercase and add an 's' to it
    elements = DB.execute("SELECT * FROM #{self.name.downcase}s")

    # #map will give us an array, which we'll populate with new models for each
    # hash inside the elements array. If the elements array is empty, so will the
    # array created by the #map be (there will be no error). In the end, we'll
    # either return an empty array or an array filled with objects
    elements.map do |instance|
      self.new(instance)
    end
  end

  def save
    if @id.nil?
      insert
    else
      update
    end
  end

  private

  def insert
    # This is the hardest method. We need to think abstractly, just like we did
    # with the initialize. To give us something to think about, let's say we have
    # two different objects:
    #   - User, with variables: @name = 'Rafa', @age = 22
    #   - Post, with variables: @title = 'Le Wagon'
    # Somehow, for each of those, we gotta execute the respective query:
    #   - DB.execute("INSERT into users (name, age) VALUES (?, ?)", @name, @age)
    #   - DB.execute("INSERT into posts (title) VALUES (?)", @title)
    # Sounds hard at first, but if we break into what is different and what is not,
    # we can break the problem into smaller parts.
    # If you pay attention, we can see that there are only four parts in the query
    # which differ from one another:
    #   - The table name (which we already know how to get)
    #   - The column names, splitted by ', '
    #   - The amout of '?', splitted by ', '
    #   - The instance variables value called after the query string, such as:
    #     - @name, @age
    #     - @title
    # If we find a way to get each of those dynamically, storing each one in a
    # variable, we'll be able to execute our query with something like:
    #   - DB.execute("INSERT into #{table_name} (#{columns}) VALUES (#{question_marks})", variables)
    # Let's see how we can get each of those

    # To get the table name in a dynamic way (only for this exercise), all we
    # need to do is take the class name in lowercase and add an 's' to it
    table_name = self.class.name.downcase + 's'

    # To get the columns, we just need the *name* of every instance variable our
    # instance has and format it to a nice string. So, something like:
    #   - @name, @age ==> "name, age"
    #   - @title      ==> "title"
    # To get all the instance variables, there's a rather simple method to use:
    columns = instance_variables
    # This method gives us an array with the instance names, as symbols.
    # So what we should have, following each example, should be something like:
    #   - columns = [:@name, :@age]
    #   - columns = [:@title]
    # Now, we need to transform that into a string, separating each instance
    # with a ', '. And what's better to join every element of an array into a
    # string than #join
    columns = columns.join(", ")
    # Now, we should have something like this:
    #   - columns = '@name, @age'
    #   - columns = '@title'
    # At last, we just need to get rid of all the '@'s. We can achieve that
    # usign the #gsub
    columns = columns.gsub("@", "")
    # Our columns are good to go

    # As we saw in the livecode, there are several ways of getting a string like:
    #   - '?, ?' (in the case of @name and @age)
    #   - '?'    (in the case of @title)
    # The method below creates an array with question marks. How many? The same
    # amount of instance variables we have. After that, we just #join then,
    # putting a ', ' in the middle
    question_marks = (["?"] * instance_variables.length).join(", ")

    # The last things we need now are the variables themselves. However, we have
    # no idea what they are, so we gotta do that dynamically.
    # We already saw a method to gather all the instance variable names, a.k.a.
    # #instance_variables. With that, we need to gather the value of each one of
    # those. So we need to do a transformation like:
    #   - [:@name, :@age]  ==> ['Rafa', 22]
    #   - [:@title]        ==> ['Le Wagon']
    # Fortunately, there's also a method for that! #instance_variable_get
    # retrieves the value of the variable with a name passed as parameter.
    # Something like:
    #   - instance_variable_get(:@name)  ==> 'Rafa'
    #   - instance_variable_get(:@title) ==> 'Le Wagon'
    #   - instance_variable_get(:@meep)  ==> nil (we do not have a variable with that name)
    # So, to achieve what we want, we #map through each instance variable name...
    values = instance_variables.map do |variable|
      # ... And get each value, storing it in an array (thanks to #map)
      instance_variable_get(variable)
    end
    # At the end, we'll have exactly what we need.

    # Finally! Now that we have all the 4 dynamic parts of our query, we can execute it!
    DB.execute("INSERT into #{table_name} (#{columns}) VALUES (#{question_marks})", values.flatten)

    # Don't forget to also set the @id of our instance, since we saved it into the DB
    # Just like we did in the previous exercises
    @id = DB.last_insert_row_id
  end

  def update
    # This is a little bit simpler than the insert method we just created, but
    # can get a little confusing as well. Let's follow the same two examples
    # (notice that this time they have @id, otherwise they wouldn't get here):
    #   - User, with variables: @id = 1, @name = 'Rafa', @age = 22
    #   - Post, with variables: @id = 1, @title = 'Le Wagon'
    # The queries we need for each case are:
    #   - DB.execute("UPDATE users SET name = ?, age = ? WHERE id = ?", @name, @age, @id)
    #   - DB.execute("UPDATE posts SET title = ? WHERE id = ?", @title, @id)
    # Take a moment to think about what are the dynamic parts of these queries.
    # ...
    # ...
    # ... already? Wow, you're fast. I hope you got to the same result as I did:
    #   - The table name (which we already saw how to get)
    #   - The 'var1 = ?, var2 = ?, ...' part
    #   - The instance variables called after the query string
    # Notice also that we will *ALWAYS* have the @id at the end, since that is
    # the last instance_variable we're gonna need (to fill the 'WHERE id = ?'),
    # so that's gonna be static, not dynamic! Therefore, we will need something like:
    #   - DB.execute("INSERT into #{table_name} SET #{variable_question_pairs} WHERE id = ?", variables_except_id, @id)
    # Let's define those variables

    # This one should be easy by now
    table_name = self.class.name.downcase + 's'

    # Now we need a way to get the variavle-question pairs. Some way to do something
    # like:
    #   - @id, @name, @age ==> 'name = ?, age = ?'
    #   - @id, @title      ==> 'title = ?'
    # In simpler words, we need to:
    #   1) get each instance_variable_name, except for id
    #   2) add a ' = ?' after *each* one of those
    #   3) join them together, separating each one with a ', '

    # The first one is simple. Although getting everything *EXCEPT* the id can
    # sound like a very tricky thing to do, we can simply get every name in an
    # array (with #instance_variables) and remove the [:@id] from it (remember,
    # the method will give us the names as symbols, not as strings!)
    variables_without_id = instance_variables - [:@id]
    # These will give us something like:
    #   - [:@name, :@age]
    #   - [:@title]

    # Having an array with these names plus an ' = ?' can be hard to figure.
    # Thinking of what we have an where we want to get, one might think it could be:
    #   - [:@name, :@age] ==> 'name = ?, age = ?'
    #   - [:@title]       ==> 'title = ?'
    # However, it would be easier if our goal (for this step) was:
    #   - [:@name, :@age] ==> ['name = ?', 'age = ?']
    #   - [:@title]       ==> ['title = ?']
    # Why? Because this way we can think of every element of the array we have
    # individually, making our job simpler. In other words, instead of trying this:
    #   - [:@name, :@age] ==> 'name = ?, age = ?'
    # We can try this:
    #   - :@name ==> 'name = ?'
    # And once we get there, apply it to every other case.
    # Enough explaining, let's get to business.
    # We have an array and we want an array as a result, so the best way to achieve
    # that is through #map...
    pairs = variables_without_id.map do |variable|
      # Having only a variable name (as symbol!!), we can get a string with that
      # name, without '@' and with the ' = ?' suffix like this:
      "#{variable.to_s.gsub('@', '')} = ?"
      # (we need to convert the name to a string if we want to use #gsub)
    end

    # Finally, the last step is to do the following transformation:
    #   - ['name = ?', 'age = ?'] ==> 'name = ?, age = ?'
    #   - ['title = ?']           ==> 'title = ?'
    # This can be easily achieved by:
    pairs = pairs.join(', ')

    # At last, we need the instance variable values, except for the id! Since I
    # explained how to retrieve them in the insert method above, the only change
    # we gotta make is to use the variables_without_id instead of #instance_variables
    values = variables_without_id.map do |variable|
      instance_variable_get(variable)
    end

    # And with that, we can now execute our query:
    DB.execute("UPDATE #{table_name} SET #{pairs} WHERE id = ?", values, @id)
  end
end
