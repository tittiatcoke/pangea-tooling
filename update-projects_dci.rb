require 'jenkins_api_client'
require 'thwait'
require_relative 'ci-tooling/lib/projects'
require_relative 'ci-tooling/lib/jenkins'

$jenkins_template_path = File.expand_path(File.dirname(File.dirname(__FILE__))) + '/jenkins-templates'

########################

projects = Projects.new

########################

$jenkins = new_jenkins
type = ['source']
dist = ['unstable']

def job_name?(release, type, name)
    return "#{name}_#{type}_#{release}"
end

def sub_upstream_scm(scm)
    return '' unless scm

    xml = nil
    case scm.type
    when 'git'
        xml = File.read("#{$jenkins_template_path}/upstream-scms/git_dci.xml")
    when 'svn'
        xml = File.read("#{$jenkins_template_path}/upstream-scms/svn.xml")
    else
        raise 'Unknown SCM type ' + scm.type
    end
    xml.gsub!('@URL@', scm.url)
    xml.gsub!('@BRANCH@', scm.branch)

    return xml
end

def create_or_update(orig_xml_config, args = {})
    xml_config = orig_xml_config.dup
    xml_config.gsub!('@UPSTREAM_SCM@', sub_upstream_scm(args[:upstream_scm]))
    xml_config.gsub!('@NAME@', args[:name] ||= '')
    xml_config.gsub!('@COMPONENT@', args[:component] ||= '')
    xml_config.gsub!('@TYPE@', args[:type] ||= '')
    xml_config.gsub!('@DIST@', args[:dist] ||= '')
    xml_config.gsub!('@DEPS@', args[:dependencies] ||= '') # Triggers always
    xml_config.gsub!('@DEPENDEES@', args[:dependees] ||= '') # Doesn't trigger
    xml_config.gsub!('@DAILY_TRIGGER@', args[:daily_trigger] ||= '')
    xml_config.gsub!('@DOWNSTREAM_TRIGGERS@', args[:downstream_triggers] ||= '') # Triggers on somewhat more advanced conditions
    xml_config.gsub!('@PACKAGING_BRANCH@', args[:packaging_branch] ||= 'kubuntu_unstable')
    xml_config.gsub!('@ARCHITECTURE@', args[:architecture] ||= '')

    job_name = args[:job_name]
    job_name ||= job_name?(args[:dist], args[:type], args[:name])
    begin
        $jenkins.job.create_or_update(job_name, xml_config)
    rescue
        retry
    end
    return job_name
end

def add_project(project)
    type = ['source']
    dist = ['unstable']
    puts "...#{project.name}...\n"
    dist.each do |release|
        type.each do |job_type|
            # Don't track deps for publishing jobs, kind of useless
            if job_type != 'publish'
                # Translate dependencies to normalized job form.
                dependencies = project.dependencies.dup || []
                dependencies.collect! do |dep|
                    dep = job_name?(release, type, dep)
                end
                dependencies.compact!

                # Translate dependees to normalized job form.
                dependees = project.dependees.dup || []
                dependees.collect! do |dependee|
                    dependee = job_name?(release, type, dependee)
                end
                dependees.compact!

                job_name = create_or_update(File.read("#{$jenkins_template_path}/#{job_type}_dci.xml"),
                                            :name => project.name,
                                            :component => project.component,
                                            :type => job_type,
                                            :dist => release,
                                            :dependencies => dependencies.join(', '),
                                            :dependees => dependees.join(', '),
                                            :upstream_scm => project.upstream_scm
                                           )
            end
        end
    end
end

project_queue = Queue.new
projects.each do |project|
    project_queue << project
end

threads = []
16.times do
    threads << Thread.new do
        while project = project_queue.pop(true) do
            begin
                add_project(project)
            rescue => e
                p e
                raise e
            end
        end
    end
end
ThreadsWait.all_waits(threads)

# Autoinstall all possibly used plugins.
installed_plugins = $jenkins.plugin.list_installed.keys
Dir.glob('jenkins-templates/**/**.xml').each do |path|
    File.readlines(path).each do |line|
        match = line.match(/.*plugin="(.+)".*/)
        next unless match and match.size == 2
        plugin = match[1].split('@').first
        next if installed_plugins.include?(plugin)
        puts "--- Installing #{plugin} ---"
        $jenkins.plugin.install(plugin)
    end
end
