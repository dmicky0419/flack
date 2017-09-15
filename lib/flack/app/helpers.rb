
# helpers
#
class Flack::App

  protected

  def debug_respond(env)

    [ 200, { 'Content-Type' => 'application/json' }, [ JSON.dump(env) ] ]
  end

  def is_response?(o)

    o.is_a?(Array) &&
    o.length == 3 &&
    o[0].is_a?(Integer) &&
    o[1].is_a?(Hash) &&
    o[2].is_a?(Array)
  end

  def respond(env, data, opts={})

    return data if opts == {} && is_response?(data)

    status = nil
    links = nil
    location = nil

    if data.is_a?(Hash)
      status = data['_status'] || data[:_status]
      links = data.delete('_links') || data.delete(:_links)
      location = data['_location'] || data[:_location]
    end

    status = status || opts[:code] || opts[:status] || 200

    headers = { 'Content-Type' => 'application/json' }
    headers['Location'] = location if location

    json = serialize(env, data, opts)

    json['_links'].merge!(links) if links

    json['_status'] = status
    json['_status_text'] = Rack::Utils::HTTP_STATUS_CODES[status]

    if e = opts[:error]; json['error'] = e; end

    [ status, headers, [ JSON.dump(json) ] ]
  end

  def try(o, meth)

    o.respond_to?(meth) ? o.send(meth) : nil
  end

  def serialize(env, data, opts)

    return serialize_array(env, data, opts) if data.is_a?(Array)

    r =
      (data.is_a?(Hash) ? Flor.dup(data) : nil) ||
      (data.nil? ? {} : nil) ||
      data.to_h

    #r['_klass'] = data.class.to_s # too rubyish
    r['_links'] = links(env)
    r['_forms'] = forms(env)

    r
  end

  def serialize_array(env, data, opts)

    { '_links' => links(env),
      '_embedded' => data.collect { |e| serialize(env, e, opts) } }
  end

  def determine_root_uri(env)

    hh = env['HTTP_HOST'] || "#{env['SERVER_NAME']}:#{env['SERVER_PORT']}"

    "#{env['rack.url_scheme']}://#{hh}#{env['SCRIPT_NAME']}"
  end

  def abs(env, href)

    return href if href[0, 4] == 'http'
    "#{env['flack.root_uri']}#{href[0, 1] == '/' ? '': '/'}#{href}"
  end

  def rel(env, href)

    return href if href[0, 4] == 'http'
    "#{env['SCRIPT_NAME']}#{href[0, 1] == '/' ? '': '/'}#{href}"
  end

  def link(env, h, type)

    l = { href: rel(env, "/#{type}") }
    l[:templated] = true if type.index('{')

    rel_right_part = type
      .gsub(/[{}]/, '')
      .gsub(/\./, '-dot')
      .gsub(/\*/, '-star')

    h["flack:#{rel_right_part}"] = l
  end

  def links(env)

    h = {}

    h['self'] = {
      href: rel(env, env['REQUEST_PATH']) }
    m = env['REQUEST_METHOD']
    h['self'][:method] = m unless %w[ GET HEAD ].include?(m)

    h['curies'] = [{
      name: 'flack',
      href: 'https://github.com/floraison/flack/blob/master/doc/rels.md#{rel}',
      templated: true }]

    link(env, h, 'executions')
    link(env, h, 'executions/{domain}')
    link(env, h, 'executions/{domain}*')
    link(env, h, 'executions/{domain}.*')
    link(env, h, 'executions/{exid}')
    link(env, h, 'executions/{id}')

    link(env, h, 'messages')
    link(env, h, 'messages/{point}')
    link(env, h, 'messages/{exid}/{point}')
    link(env, h, 'messages/{exid}')
    link(env, h, 'messages/{id}')

    h
  end

  def forms(env)

    h = {}

    h['flack:forms/message'] = {
      action: rel(env, '/message'),
      method: 'POST',
      _inputs: { 'flack:forms/message-content' => { type: 'json' } } }

    h
  end

  def respond_bad_request(env, error=nil)

    respond(env, {}, code: 400, error: error)
  end

  def respond_not_found(env, error=nil)

    respond(env, {}, code: 404, error: error)
  end
end

