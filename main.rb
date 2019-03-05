require "httparty"
require "json"
require "time"

class DockerRegistry
  include HTTParty
  base_uri "https://#{ENV["REGISTRY_DOMAIN"]}"

  def repositories
    self.class.get("/v2/_catalog", { format: :json })["repositories"]
  end

  def tags(repo)
    self.class.get("/v2/#{repo}/tags/list", { format: :json })["tags"]
  end

  def digest(repo, tag)
    self.class.get(
      "/v2/#{repo}/manifests/#{tag}",
      {
        headers: {
          Accept: "application/vnd.docker.distribution.manifest.v2+json",
        },
      }
    ).headers["docker-content-digest"]
  end

  def delete_tag(repo, digest)
    res = self.class.delete("/v2/#{repo}/manifests/#{digest}")
    if res.code != 202
      puts res
    end
  end

  def created_at(repo, tag)
    self.class.get("/v2/#{repo}/manifests/#{tag}", { format: :json })["history"]
      .map { |h| JSON.parse(h["v1Compatibility"]) }
      .map { |o| Time.parse(o["created"]) }
      .max rescue nil
  end
end

reg = DockerRegistry.new
reg.repositories.map do |repo|
  reg.tags(repo)&.map do |tag|
    next unless /^pr-/ =~ tag
    if (reg.created_at(repo, tag) || Time.local(2030, 1, 1, 0, 0, 0)) < Time.local(2019, 2, 1, 0, 0, 0)
      puts "#{repo} #{tag}"
      digest = reg.digest(repo, tag)
      reg.delete_tag(repo, digest)
    end
  end
end

