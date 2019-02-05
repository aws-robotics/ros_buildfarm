<project>
  <actions/>
  <description>Generated at @ESCAPE(now_str) from template '@ESCAPE(template_name)'@
@[if disabled]
but disabled since the package is blacklisted (or not whitelisted) in the configuration file@
@[end if]@
@ </description>
  <keepDependencies>false</keepDependencies>
  <properties>
@(SNIPPET(
    'property_log-rotator',
    days_to_keep=730,
    num_to_keep=100,
))@
@[if job_priority is not None]@
@(SNIPPET(
    'property_job-priority',
    priority=job_priority,
))@
@[end if]@
@(SNIPPET(
    'property_requeue-job',
))@
@{
parameters = [
    {
        'type': 'boolean',
        'name': 'skip_cleanup',
        'description': 'Skip cleanup of build artifacts as well as rosdoc index',
    },
    {
        'type': 'string',
        'name': 'foundation_packages',
        'default_value': ' '.join(foundation_packages),
        'description': 'Package(s) to be installed prior to any packages detected for installation by rosdep (space-separated)',
    },
    {
        'type': 'string',
        'name': 'repos_files',
        'default_value': ' '.join(repos_files),
        'description': 'URL(s) of repos file(s) containing the list of packages to be built (space-separated)',
    },
    {
        'type': 'string',
        'name': 'test_branch',
        'default_value': '',
        'description': 'Branch to attempt to checkout before doing batch job',
    },
    {
        'type': 'string',
        'name': 'build_ignore',
        'default_value': ' '.join(build_ignore),
        'description': 'Package name(s) which should be excluded from the build (space-separated)',
    },
    {
        'type': 'string',
        'name': 'packages_select',
        'default_value': '',
        'description': 'Package(s) to be built (space-separated), or blank for ALL',
    },
    {
        'type': 'string',
        'name': 'depth_before',
        'default_value': '0',
        'description': 'Number of forward dependencies of selected packages to be include in scope',
    },
    {
        'type': 'string',
        'name': 'depth_after',
        'default_value': '0',
        'description': 'Number of reverse dependencies of selected packages to be include in scope',
    },
]
}@
@(SNIPPET(
    'property_parameters-definition',
    parameters=parameters,
))@
  </properties>
  <scmCheckoutRetryCount>2</scmCheckoutRetryCount>
  <assignedNode>@(node_label)</assignedNode>
  <canRoam>false</canRoam>
  <disabled>@('true' if disabled else 'false')</disabled>
  <blockBuildWhenDownstreamBuilding>false</blockBuildWhenDownstreamBuilding>
  <blockBuildWhenUpstreamBuilding>false</blockBuildWhenUpstreamBuilding>
  <triggers>
@[if trigger_timer is not None]@
@(SNIPPET(
    'trigger_timer',
    spec=trigger_timer,
))@
@[end if]@
  </triggers>
  <concurrentBuild>true</concurrentBuild>
  <builders>
@(SNIPPET(
    'builder_system-groovy_check-free-disk-space',
))@
@(SNIPPET(
    'builder_shell_docker-info',
))@
@(SNIPPET(
    'builder_check-docker',
    os_name=os_name,
    os_code_name=os_code_name,
    arch=arch,
))@
@(SNIPPET(
    'builder_shell_clone-ros-buildfarm',
    ros_buildfarm_repository=ros_buildfarm_repository,
    wrapper_scripts=wrapper_scripts,
))@
@(SNIPPET(
    'builder_shell_key-files',
    script_generating_key_files=script_generating_key_files,
))@
@[if underlay_source_job is not None]@
@(SNIPPET(
    'builder_shell',
    script='\n'.join([
        'echo "# BEGIN SECTION: Prepare package underlay"',
    ]),
))@
@(SNIPPET(
    'copy_artifacts',
    artifacts=[
      '*.tar.bz2',
    ],
    project=underlay_source_job,
    target_directory='$WORKSPACE/underlay',
))@
@(SNIPPET(
    'builder_shell',
    script='\n'.join([
        'tar -xjf $WORKSPACE/underlay/*.tar.bz2 -C $WORKSPACE/underlay',
        'echo "# END SECTION"',
    ]),
))@
@[end if]@
@(SNIPPET(
    'builder_shell',
    script='\n'.join([
        'rm -fr $WORKSPACE/docker_generating_dockers',
        'mkdir -p $WORKSPACE/docker_generating_dockers',
        '',
        '# monitor all subprocesses and enforce termination',
        'python3 -u $WORKSPACE/ros_buildfarm/scripts/subprocess_reaper.py $$ --cid-file $WORKSPACE/docker_generating_dockers/docker.cid > $WORKSPACE/docker_generating_dockers/subprocess_reaper.log 2>&1 &',
        '# sleep to give python time to startup',
        'sleep 1',
        '',
        '# create a unique dockerfile name prefix',
        'export DOCKER_IMAGE_PREFIX=$(date +%s.%N)',
        '',
        '# generate Dockerfile, build and run it',
        '# generating the Dockerfiles for the actual CI tasks',
        'echo "# BEGIN SECTION: Generate Dockerfile - CI tasks"',
        'export TZ="%s"' % timezone,
        'export UNDERLAY_JOB_SPACE=$WORKSPACE/underlay/ros%d-linux' % (ros_version),
        'export PYTHONPATH=$WORKSPACE/ros_buildfarm:$PYTHONPATH',
        'python3 -u $WORKSPACE/ros_buildfarm/scripts/ci/run_ci_job.py' +
        ' ' + rosdistro_name +
        ' ' + os_name +
        ' ' + os_code_name +
        ' ' + arch +
        ' ' + ' '.join(repository_args) +
        ' --build-tool ' + build_tool +
        ' --ros-version ' + str(ros_version) +
        ' --env-vars ' + ' '.join(build_environment_variables) +
        ' --dockerfile-dir $WORKSPACE/docker_generating_dockers' +
        ' --repos-file-urls $repos_files' +
        ' --test-branch "$test_branch"' +
        ' --skip-rosdep-keys ' + ' '.join(skip_rosdep_keys) +
        ' --build-ignore $build_ignore' +
        ' --foundation-packages $foundation_packages' +
        ' --workspace-mount-point' +
        (' /tmp/ws' if not underlay_source_paths else \
         ''.join([' /tmp/ws%s' % (i or '') for i in range(len(underlay_source_paths))]) +
         ' /tmp/ws_overlay') +
        ' --depth-before $depth_before' +
        ' --depth-after $depth_after' +
        ' --packages-select $packages_select',
        'echo "# END SECTION"',
        '',
        'echo "# BEGIN SECTION: Build Dockerfile - generating CI tasks"',
        'cd $WORKSPACE/docker_generating_dockers',
        'python3 -u $WORKSPACE/ros_buildfarm/scripts/misc/docker_pull_baseimage.py',
        'docker build --force-rm -t $DOCKER_IMAGE_PREFIX.ci_task_generation.%s .' % (rosdistro_name),
        'echo "# END SECTION"',
        '',
        'echo "# BEGIN SECTION: Run Dockerfile - generating CI tasks"',
        'rm -fr $WORKSPACE/docker_create_workspace',
        'rm -fr $WORKSPACE/docker_build_and_install',
        'rm -fr $WORKSPACE/docker_build_and_test',
        'mkdir -p $WORKSPACE/docker_create_workspace',
        'mkdir -p $WORKSPACE/docker_build_and_install',
        'mkdir -p $WORKSPACE/docker_build_and_test',
        'docker run' +
        ' --rm ' +
        ' --cidfile=$WORKSPACE/docker_generating_dockers/docker.cid' +
        ' -e=HOME=/home/buildfarm' +
        ' -v $WORKSPACE/ros_buildfarm:/tmp/ros_buildfarm:ro' +
        ' -v $WORKSPACE/docker_create_workspace:/tmp/docker_create_workspace' +
        ' -v $WORKSPACE/docker_build_and_install:/tmp/docker_build_and_install' +
        ' -v $WORKSPACE/docker_build_and_test:/tmp/docker_build_and_test' +
        ' $DOCKER_IMAGE_PREFIX.ci_task_generation.%s' % (rosdistro_name),
        'cd -',  # restore pwd when used in scripts
        'echo "# END SECTION"',
    ]),
))@
@(SNIPPET(
    'builder_shell',
    script='\n'.join([
        '# monitor all subprocesses and enforce termination',
        'python3 -u $WORKSPACE/ros_buildfarm/scripts/subprocess_reaper.py $$ --cid-file $WORKSPACE/docker_create_workspace/docker.cid > $WORKSPACE/docker_create_workspace/subprocess_reaper.log 2>&1 &',
        '# sleep to give python time to startup',
        'sleep 1',
        '',
        '# create a unique dockerfile name prefix',
        'export DOCKER_IMAGE_PREFIX=$(date +%s.%N)',
        '',
        'echo "# BEGIN SECTION: Build Dockerfile - create workspace"',
        '# build and run create_workspace Dockerfile',
        'cd $WORKSPACE/docker_create_workspace',
        'python3 -u $WORKSPACE/ros_buildfarm/scripts/misc/docker_pull_baseimage.py',
        'docker build --force-rm -t $DOCKER_IMAGE_PREFIX.ci_create_workspace.%s .' % (rosdistro_name),
        'echo "# END SECTION"',
        '',
        '# Ensure an egg_info exists in the ros_buildfarm package (for Colcon entry points)',
        'python3 -u $WORKSPACE/ros_buildfarm/setup.py egg_info -e $WORKSPACE/ros_buildfarm',
        '',
        'echo "# BEGIN SECTION: Run Dockerfile - create workspace"',
        'rm -fr $WORKSPACE/ws/src',
        'mkdir -p $WORKSPACE/ws/src',
        '\n'.join(['mkdir -p %s' % (dir) for dir in underlay_source_paths or []]),
        'docker run' +
        ' --rm ' +
        ' --cidfile=$WORKSPACE/docker_create_workspace/docker.cid' +
        ' -v $WORKSPACE/ros_buildfarm:/tmp/ros_buildfarm:ro' +
        (' -v $WORKSPACE/ws:/tmp/ws' if not underlay_source_paths else \
         ''.join([' -v %s:/tmp/ws%s/install_isolated' % (space, i or '') for i, space in enumerate(underlay_source_paths)]) +
         ' -v $WORKSPACE/ws:/tmp/ws_overlay') +
        ' $DOCKER_IMAGE_PREFIX.ci_create_workspace.%s' % (rosdistro_name),
        'cd -',  # restore pwd when used in scripts
        'echo "# END SECTION"',
    ]),
))@
@(SNIPPET(
    'builder_shell',
    script='\n'.join([
        'echo "# BEGIN SECTION: Copy dependency list"',
        '/bin/cp -f $WORKSPACE/ws/install_list.txt $WORKSPACE/docker_build_and_test/',
        '/bin/cp -f $WORKSPACE/ws/install_list.txt $WORKSPACE/docker_build_and_install/',
        'echo "# END SECTION"',
    ]),
))@
@(SNIPPET(
    'builder_shell',
    script='\n'.join([
        '# monitor all subprocesses and enforce termination',
        'python3 -u $WORKSPACE/ros_buildfarm/scripts/subprocess_reaper.py $$ --cid-file $WORKSPACE/docker_build_and_install/docker.cid > $WORKSPACE/docker_build_and_install/subprocess_reaper.log 2>&1 &',
        '# sleep to give python time to startup',
        'sleep 1',
        '',
        '# create a unique dockerfile name prefix',
        'export DOCKER_IMAGE_PREFIX=$(date +%s.%N)',
        '',
        'echo "# BEGIN SECTION: Build Dockerfile - build and install"',
        '# build and run build and install Dockerfile',
        'cd $WORKSPACE/docker_build_and_install',
        'python3 -u $WORKSPACE/ros_buildfarm/scripts/misc/docker_pull_baseimage.py',
        'docker build --force-rm -t $DOCKER_IMAGE_PREFIX.ci_build_and_install.%s .' % (rosdistro_name),
        'echo "# END SECTION"',
        '',
        'echo "# BEGIN SECTION: ccache stats (before)"',
        'mkdir -p $HOME/.ccache',
        'docker run' +
        ' --rm ' +
        ' --cidfile=$WORKSPACE/docker_build_and_install/docker_ccache_before.cid' +
        ' -e CCACHE_DIR=/home/buildfarm/.ccache' +
        ' -v $HOME/.ccache:/home/buildfarm/.ccache' +
        ' $DOCKER_IMAGE_PREFIX.ci_build_and_install.%s' % (rosdistro_name) +
        ' "ccache -s"',
        'echo "# END SECTION"',
        '',
        'echo "# BEGIN SECTION: Run Dockerfile - build and install"',
        'docker run' +
        ' --rm ' +
        ' --cidfile=$WORKSPACE/docker_build_and_install/docker.cid' +
        ' -e CCACHE_DIR=/home/buildfarm/.ccache' +
        ' -v $HOME/.ccache:/home/buildfarm/.ccache' +
        ' -v $WORKSPACE/ros_buildfarm:/tmp/ros_buildfarm:ro' +
        (' -v $WORKSPACE/ws:/tmp/ws' if not underlay_source_paths else \
         ''.join([' -v %s:/tmp/ws%s/install_isolated' % (space, i or '') for i, space in enumerate(underlay_source_paths)]) +
         ' -v $WORKSPACE/ws:/tmp/ws_overlay') +
        ' $DOCKER_IMAGE_PREFIX.ci_build_and_install.%s' % (rosdistro_name),
        'cd -',  # restore pwd when used in scripts
        'echo "# END SECTION"',
        '',
        'echo "# BEGIN SECTION: ccache stats (after)"',
        'docker run' +
        ' --rm ' +
        ' --cidfile=$WORKSPACE/docker_build_and_install/docker_ccache_after.cid' +
        ' -e CCACHE_DIR=/home/buildfarm/.ccache' +
        ' -v $HOME/.ccache:/home/buildfarm/.ccache' +
        ' $DOCKER_IMAGE_PREFIX.ci_build_and_install.%s' % (rosdistro_name) +
        ' "ccache -s"',
        'echo "# END SECTION"',
    ]),
))@
@(SNIPPET(
    'builder_shell',
    script='\n'.join([
        'echo "# BEGIN SECTION: Compress install space"',
        'tar -cjf $WORKSPACE/ros%d-%s-linux-%s-%s-ci.tar.bz2 ' % (ros_version, rosdistro_name, os_code_name, arch) +
        ' -C $WORKSPACE/ws' +
        ' --transform "s/^install_isolated/ros%d-linux/"' % (ros_version) +
        ' install_isolated',
        'echo "# END SECTION"',
    ]),
))@
@(SNIPPET(
    'builder_shell',
    script='\n'.join([
        '# monitor all subprocesses and enforce termination',
        'python3 -u $WORKSPACE/ros_buildfarm/scripts/subprocess_reaper.py $$ --cid-file $WORKSPACE/docker_build_and_test/docker.cid > $WORKSPACE/docker_build_and_test/subprocess_reaper.log 2>&1 &',
        '# sleep to give python time to startup',
        'sleep 1',
        '',
        '# create a unique dockerfile name prefix',
        'export DOCKER_IMAGE_PREFIX=$(date +%s.%N)',
        '',
        'echo "# BEGIN SECTION: Build Dockerfile - build and test"',
        '# build and run build and test Dockerfile',
        'cd $WORKSPACE/docker_build_and_test',
        'python3 -u $WORKSPACE/ros_buildfarm/scripts/misc/docker_pull_baseimage.py',
        'docker build --force-rm -t $DOCKER_IMAGE_PREFIX.ci_build_and_test.%s .' % (rosdistro_name),
        'echo "# END SECTION"',
        '',
        'echo "# BEGIN SECTION: ccache stats (before)"',
        'mkdir -p $HOME/.ccache',
        'docker run' +
        ' --rm ' +
        ' --cidfile=$WORKSPACE/docker_build_and_test/docker_ccache_before.cid' +
        ' -e CCACHE_DIR=/home/buildfarm/.ccache' +
        ' -v $HOME/.ccache:/home/buildfarm/.ccache' +
        ' $DOCKER_IMAGE_PREFIX.ci_build_and_test.%s' % (rosdistro_name) +
        ' "ccache -s"',
        'echo "# END SECTION"',
        '',
        'echo "# BEGIN SECTION: Run Dockerfile - build and test"',
        'rm -fr $WORKSPACE/ws/test_results',
        'mkdir -p $WORKSPACE/ws/test_results',
        'docker run' +
        ' --rm ' +
        ' --cidfile=$WORKSPACE/docker_build_and_test/docker.cid' +
        ' -e CCACHE_DIR=/home/buildfarm/.ccache' +
        ' -v $HOME/.ccache:/home/buildfarm/.ccache' +
        ' -v $WORKSPACE/ros_buildfarm:/tmp/ros_buildfarm:ro' +
        (' -v $WORKSPACE/ws:/tmp/ws' if not underlay_source_paths else \
         ''.join([' -v %s:/tmp/ws%s/install_isolated' % (space, i or '') for i, space in enumerate(underlay_source_paths)]) +
         ' -v $WORKSPACE/ws:/tmp/ws_overlay') +
        ' $DOCKER_IMAGE_PREFIX.ci_build_and_test.%s' % (rosdistro_name),
        'cd -',  # restore pwd when used in scripts
        'echo "# END SECTION"',
        '',
        'echo "# BEGIN SECTION: ccache stats (after)"',
        'docker run' +
        ' --rm ' +
        ' --cidfile=$WORKSPACE/docker_build_and_test/docker_ccache_after.cid' +
        ' -e CCACHE_DIR=/home/buildfarm/.ccache' +
        ' -v $HOME/.ccache:/home/buildfarm/.ccache' +
        ' $DOCKER_IMAGE_PREFIX.ci_build_and_test.%s' % (rosdistro_name) +
        ' "ccache -s"',
        'echo "# END SECTION"',
    ]),
))@
@(SNIPPET(
    'builder_shell',
    script='\n'.join([
        'if [ "$skip_cleanup" = "false" ]; then',
        'echo "# BEGIN SECTION: Clean up to save disk space on agents"',
        'rm -fr ws/build_isolated',
        'rm -fr ws/devel_isolated',
        'rm -fr ws/install_isolated',
        'echo "# END SECTION"',
        'fi',
    ]),
))@
@[if collate_test_stats]@
@(SNIPPET(
    'builder_shell',
    script='\n'.join([
        'echo "# BEGIN SECTION: Create collated test stats dir"',
        'rm -fr $WORKSPACE/collated_test_stats',
        'mkdir -p $WORKSPACE/collated_test_stats',
        'echo "# END SECTION"',
    ]),
))@
@[end if]@
  </builders>
  <publishers>
@(SNIPPET(
    'publisher_warnings',
    unstable_threshold='',
))@
@(SNIPPET(
    'archive_artifacts',
    artifacts=[
      'ros%d-%s-linux-%s-%s-ci.tar.bz2' % (ros_version, rosdistro_name, os_code_name, arch),
    ],
))@
@(SNIPPET(
    'publisher_xunit',
    pattern='ws/test_results/**/*.xml',
))@
@[if collate_test_stats]@
@(SNIPPET(
    'publisher_groovy-postbuild',
    script='\n'.join([
        '// COLLATE BUILD TEST RESULTS AND EXPORT BUILD HISTORY FOR WIKI',
        'import jenkins.model.Jenkins',
        'import hudson.FilePath',
        '',
        '@Grab(\'org.yaml:snakeyaml:1.17\')',
        'import org.yaml.snakeyaml.Yaml',
        'import org.yaml.snakeyaml.DumperOptions',
        '',
        'manager.listener.logger.println("# BEGIN SECTION: Collate test results for wiki.")',
        '',
        '// nr of builds to include in history',
        'final num_build_hist = 5',
        '',
        'try {',
        '  def data = [',
        '    "history" : []',
        '  ]',
        '',
        '  // gather info on tests of current build',
        '  def tresult = manager.build.getAction(hudson.tasks.junit.TestResultAction.class)?.result',
        '  if (tresult) {',
        '    data.latest_build = [',
        '      "skipped" : tresult.skipCount,',
        '      "failed" : tresult.failCount,',
        '      "total" : tresult.totalCount',
        '    ]',
        '  }',
        '  else {',
        '    manager.listener.logger.println("No test result action for last build, skipping gathering statistics for it.")',
        '  }',
        '',
        '',
        '  // get access to the job of the running build',
        '  def job_name = manager.build.getEnvironment(manager.listener).get(\'JOB_NAME\')',
        '  manager.listener.logger.println("Collating test statistics for \'${job_name}\'.")',
        '  def job = Jenkins.instance.getItem(job_name)',
        '  if (job == null) {',
        '    manager.listener.logger.println("No such job: \'${job_name}\'.")',
        '    return',
        '  }',
        '',
        '  // store base info',
        '  data.base_url = Jenkins.instance.getRootUrl()',
        '  data.total_builds = job.builds.size()',
        '  data.job_health = job.getBuildHealth().getScore()',
        '  data.job_health_icon = job.getBuildHealth().getIconClassName()',
        '',
        '  // retrieve info on last N builds of this job',
        '  job.builds.take(num_build_hist).each { b ->',
        '    tresult = b.getAction(hudson.tasks.junit.TestResultAction.class)?.result',
        '    if (tresult) {',
        '      data.history << [',
        '        "build_id" : b.id as Integer,',
        '        "uri" : b.url,',
        '        "stamp" : b.getStartTimeInMillis() / 1e3,',
        '        "result" :  b.result.toString().toLowerCase(),',
        '        "tests" : [',
        '          "skipped" : tresult.skipCount,',
        '          "failed" : tresult.failCount,',
        '          "total" : tresult.totalCount',
        '        ]',
        '      ]',
        '    }',
        '  }',
        '',
        '  // write out info to file',
        '  def DumperOptions options = new DumperOptions()',
        '  options.setPrettyFlow(true)',
        '  options.setDefaultFlowStyle(DumperOptions.FlowStyle.BLOCK)',
        '  def yaml_output = new Yaml(options).dump([\'dev_job_data\' : data])',
        '',
        '  def fp = new FilePath(manager.build.workspace, "collated_test_stats/results.yaml")',
        '  if(fp != null)',
        '    fp.write(yaml_output, null)',
        '  else',
        '    manager.listener.logger.println("Could not write to yaml file (fp == null)")',
        '',
        '} finally {',
        '  manager.listener.logger.println("# END SECTION")',
        '}',
    ]),
))
@(SNIPPET(
    'publisher_publish-over-ssh',
    config_name='docs',
    remote_directory='%s/ci_jobs' % (rosdistro_name),
    source_files=[
        'collated_test_stats/results.yaml'
    ],
    remove_prefix='collated_test_stats',
))@
@[end if]@
  </publishers>
  <buildWrappers>
@[if timeout_minutes is not None]@
@(SNIPPET(
    'build-wrapper_build-timeout',
    timeout_minutes=timeout_minutes,
))@
@[end if]@
@(SNIPPET(
    'build-wrapper_timestamper',
))@
  </buildWrappers>
</project>
