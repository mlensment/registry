class Zonefile
  RECORDS = [:mx, :a, :a4, :ns, :cname, :txt, :ptr, :srv, :soa, :ds,
             :dnskey, :rrsig, :nsec, :nsec3, :nsec3param, :tlsa, :naptr]

  attr_accessor(*RECORDS, :ttl, :origin)

  def initialize(obj = {})
    RECORDS.each do |x|
      if x == :soa
        send("#{x}=", {})
      else
        send("#{x}=", [])
      end
    end

    obj.each do |k, v|
      send("#{k}=", v)
    end
  end

  def new_serial
    base = sprintf('%04d%02d%02d', Time.now.year, Time.now.month, Time.now.day)

    if soa[:serial]
      if base == soa[:serial].first(8)
        sequence = soa[:serial].last(2).to_i + 1
        soa[:serial] = "#{base}#{sprintf('%02d', sequence)}"
        return soa[:serial]
      end
    end

    soa[:serial] = soa[:serial] = "#{base}00"
  end

  # rubocop:disable Metrics/MethodLength
  # rubocop: disable Metrics/PerceivedComplexity
  # rubocop: disable Metrics/CyclomaticComplexity
  def generate
    out = <<-eos
$ORIGIN #{origin}        ; designates the start of this zone file in the namespace
$TTL #{ttl}              ; default expiration time of all resource records without their own TTL value

#{soa[:origin]}  #{soa[:ttl]} IN SOA #{soa[:primary_ns]} #{soa[:email]} (
                      #{sprintf('%-13s', soa[:serial])}; serial number
                      #{sprintf('%-13s', soa[:refresh])}; refresh, seconds
                      #{sprintf('%-13s', soa[:retry])}; retry, seconds
                      #{sprintf('%-13s', soa[:expire])}; expire, seconds
                      #{sprintf('%-13s', soa[:minimumTTL])}; minimum TTL, seconds
                      )
    eos

    ns.each do |ns|
      out <<  "#{ns[:name]}  #{ns[:ttl]} #{ns[:class]} NS  #{ns[:host]}\n"
    end

    out << "\n; Zone MX Records\n" unless mx.empty?

    mx.each do |mx|
      out << "#{mx[:name]} #{mx[:ttl]} #{mx[:class]} MX  #{mx[:pri]} #{mx[:host]}\n"
    end

    out << "\n; Zone A Records\n" unless a.empty?

    a.each do |a|
      out <<  "#{a[:name]}  #{a[:ttl]}  #{a[:class]}  A #{a[:host]}\n"
    end

    out << "\n; Zone CNAME Records\n" unless cname.empty?

    cname.each do |cn|
      out << "#{cn[:name]} #{cn[:ttl]} #{cn[:class]} CNAME #{cn[:host]}\n"
    end

    out << "\n; Zone AAAA Records\n" unless a4.empty?

    a4.each do |a4|
      out << "#{a4[:name]} #{a4[:ttl]} #{a4[:class]} AAAA  #{a4[:host]}\n"
    end

    out << "\n; Zone TXT Records\n" unless txt.empty?

    txt.each do |tx|
      out << "#{tx[:name]} #{tx[:ttl]} #{tx[:class]} TXT #{tx[:text]}\n"
    end

    out << "\n; Zone SRV Records\n" unless srv.empty?

    srv.each do |srv|
      out << "#{srv[:name]}  #{srv[:ttl]}  #{srv[:class]}  SRV #{srv[:pri]} "\
             "#{srv[:weight]} #{srv[:port]}  #{srv[:host]}\n"
    end

    out << "\n; Zone PTR Records\n" unless ptr.empty?

    ptr.each do |ptr|
      out << "#{ptr[:name]}  #{ptr[:ttl]}  #{ptr[:class]}  PTR #{ptr[:host]}\n"
    end

    out << "\n; Zone DS Records\n" unless ds.empty?

    ds.each do |ds|
      out << "#{ds[:name]} #{ds[:ttl]} #{ds[:class]} DS #{ds[:key_tag]} #{ds[:algorithm]} "\
             "#{ds[:digest_type]} #{ds[:digest]}\n"
    end

    out << "\n; Zone NSEC Records\n" unless self.ds.empty?

    nsec.each do |nsec|
      out << "#{nsec[:name]} #{nsec[:ttl]} #{nsec[:class]} NSEC #{nsec[:next]} #{nsec[:types]}\n"
    end

    out << "\n; Zone NSEC3 Records\n" unless self.ds.empty?

    nsec3.each do |nsec3|
      out << "#{nsec3[:name]} #{nsec3[:ttl]} #{nsec3[:class]} NSEC3 #{nsec3[:algorithm]} "\
             "#{nsec3[:flags]} #{nsec3[:iterations]} #{nsec3[:salt]} #{nsec3[:next]} #{nsec3[:types]}\n"
    end

    out << "\n; Zone NSEC3PARAM Records\n" unless self.ds.empty?

    nsec3param.each do |nsec3param|
      out << "#{nsec3param[:name]} #{nsec3param[:ttl]} #{nsec3param[:class]} NSEC3PARAM "\
             "#{nsec3param[:algorithm]} #{nsec3param[:flags]} #{nsec3param[:iterations]} #{nsec3param[:salt]}\n"
    end

    out << "\n; Zone DNSKEY Records\n" unless self.ds.empty?

    dnskey.each do |dnskey|
      out << "#{dnskey[:name]} #{dnskey[:ttl]} #{dnskey[:class]} DNSKEY #{dnskey[:flag]} "\
             "#{dnskey[:protocol]} #{dnskey[:algorithm]} #{dnskey[:public_key]}\n"
    end

    out << "\n; Zone RRSIG Records\n" unless self.ds.empty?

    rrsig.each do |rrsig|
      out << "#{rrsig[:name]} #{rrsig[:ttl]} #{rrsig[:class]} RRSIG #{rrsig[:type_covered]} "\
             "#{rrsig[:algorithm]} #{rrsig[:labels]} #{rrsig[:original_ttl]} #{rrsig[:expiration]} "\
             "#{rrsig[:inception]} #{rrsig[:key_tag]} #{rrsig[:signer]} #{rrsig[:signature]}\n"
    end

    out << "\n; Zone TLSA Records\n" unless tlsa.empty?

    tlsa.each do |tlsa|
      out << "#{tlsa[:name]} #{tlsa[:ttl]} #{tlsa[:class]} TLSA #{tlsa[:certificate_usage]} "\
             "#{tlsa[:selector]} #{tlsa[:matching_type]} #{tlsa[:data]}\n"
    end

    out << "\n; Zone NAPTR Records\n" unless self.ds.empty?

    naptr.each do |naptr|
      out << "#{naptr[:name]} #{naptr[:ttl]} #{naptr[:class]} NAPTR #{naptr[:order]} "\
             "#{naptr[:preference]} #{naptr[:flags]} #{naptr[:service]} #{naptr[:regexp]} #{naptr[:replacement]}\n"
    end

    out
  end
end