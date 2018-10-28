class NoteGit
  require 'uri'
  require 'net/http'
  require 'json'

  YNOTE_CSTK = 'MVkukR1M'
  YNOTE_SESS = 'v2|hlO8qXHJuRPzh4UWRHQK0euhMwuOLPL0OM0fqSOfYWR6u64qL0Mzf0zMRHUA0HYM0UG64wz0LY5RlfP4U5hfP40Tz0fPB64kW0;'
  YNOTE_LOGIN = '3||1540543407940;'

  def start
    find_blog_folder()
  end

  def root_path
    params = {
      'path' => '/',
      'entire' => true,
      'purge' => false,
      'cstk' => YNOTE_CSTK
    }
    url = "https://note.youdao.com/yws/api/personal/file?method=getByPath&keyfrom=web&cstk=MVkukR1M"
    request_func(url, params, 'POST')
  end

  def find_blog_folder
    params = {
      'path' => '/',
      'dirOnly' => true,
      'f' => true,
      'cstk' => YNOTE_CSTK
    }

    url = "https://note.youdao.com/yws/api/personal/file?method=listEntireByParentPath&keyfrom=web&cstk=MVkukR1M"
    data = request_func(url, params, 'POST')

    puts "Please input the folder name, you want to Synchronization:"
    folder_name = gets

    folder_id = nil
    data.each do |d|
      if d["fileEntry"]["name"].downcase.include?(folder_name.chomp)
        folder_id = d["fileEntry"]["id"]
      end
    end
    get_folder_articles(folder_id)
  end

  def get_folder_articles(folder_id)
    url = "https://note.youdao.com/yws/api/personal/file/#{folder_id}?all=true&f=true&len=30&sort=1&isReverse=false&method=listPageByParentId&keyfrom=web&cstk=MVkukR1M"
    data = request_func(url, nil, 'GET')
    puts "Please input _post path(ex: /Users/username/workspace/example.github.io/_posts/):"
    blog_path = gets
    blog_path.chomp!
    data["entries"].each do |d|
      article_id = d["fileEntry"]["id"]
      article_name = d["fileEntry"]["name"]
      article_content = get_article_content(article_id)
      create_time = d["fileEntry"]["createTimeForSort"]
      store_article_to_blog(article_name, create_time, article_content, blog_path)
    end
  end

  def get_article_content(article_id)
    url = "https://note.youdao.com/yws/api/personal/sync?method=download&keyfrom=web&cstk=MVkukR1M"
    params = {
      'fileId' => article_id,
      'version' => -1,
      'read' => true,
      'cstk' => YNOTE_CSTK
    }

    request_func(url, params, 'POST')
  end

  def store_article_to_blog(article_name, create_time, article_content, blog_path)
    file_name = Time.at(create_time).strftime("%Y-%m-%d") + '-' + article_name.gsub(' ', '-')
    content_tag = <<~EOF
      ---
      layout: post
      title: #{article_name.gsub('.md', '')}
      date: #{Time.at create_time}
      categories: nginx
      ---

    EOF

    article_content = content_tag + article_content.force_encoding("UTF-8")
    file = File.new(blog_path + file_name, 'w+')
    file.syswrite(article_content)
    puts '*' * 123
    puts "synchronized #{article_name} created #{file_name} to #{blog_path}"
    puts '*' * 123
  end

  def request_func(url, params, method = 'GET')
    url = URI(url)
    Net::HTTP.start(url.host, url.port, :use_ssl => true) do |http|
      if method == 'POST'
        request = Net::HTTP::Post.new(url)
        request.set_form_data(params)
      elsif method == 'GET'
        request = Net::HTTP::Get.new(url)
      end
      request["Cookie"] = "YNOTE_SESS=" + YNOTE_SESS + ' ' + "YNOTE_LOGIN=" +  YNOTE_LOGIN
      request["Cache-Control"] = 'no-cache'
      response = http.request(request)
      case response
      when Net::HTTPSuccess
        if response.header.content_type == 'text/json'
          JSON.parse response.body
        elsif response.header.content_type == 'text/markdown'
          response.body
        end
      when Net::HTTPUnauthorized
        {'error' => "#{response.message}: username and password set and correct?"}
      when Net::HTTPServerError
        {'error' => "#{response.message}: try again later?"}
      else
        {'error' => response.message}
      end
    end
  end
  private :request_func
end
