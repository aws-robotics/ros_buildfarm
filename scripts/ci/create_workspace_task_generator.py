#!/usr/bin/env python3

# Copyright 2018 Open Source Robotics Foundation, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import argparse
import os
import sys

from apt import Cache

from ros_buildfarm.argument import \
    add_argument_distribution_repository_key_files
from ros_buildfarm.argument import add_argument_distribution_repository_urls
from ros_buildfarm.argument import add_argument_env_vars
from ros_buildfarm.argument import add_argument_dockerfile_dir
from ros_buildfarm.common import get_binary_package_versions
from ros_buildfarm.common import get_distribution_repository_keys
from ros_buildfarm.common import get_user_id
from ros_buildfarm.templates import create_dockerfile


def main(argv=sys.argv[1:]):
    parser = argparse.ArgumentParser(
        description="Generate a 'Dockerfile' for the CI job")
    parser.add_argument(
        '--rosdistro-name',
        required=True,
        help='The name of the ROS distro to identify the setup file to be '
             'sourced')
    parser.add_argument(
        '--workspace-root',
        nargs='+',
        help='The root path of the workspace to compile')
    parser.add_argument(
        '--os-name',
        required=True,
        help="The OS name (e.g. 'ubuntu')")
    parser.add_argument(
        '--os-code-name',
        required=True,
        help="The OS code name (e.g. 'xenial')")
    parser.add_argument(
        '--arch',
        required=True,
        help="The architecture (e.g. 'amd64')")
    add_argument_distribution_repository_urls(parser)
    add_argument_distribution_repository_key_files(parser)
    add_argument_dockerfile_dir(parser)
    add_argument_env_vars(parser)
    parser.add_argument(
        '--repos-file-urls',
        help='URLs of repos files to import with vcs.',
        nargs='*',
        required=True)
    parser.add_argument(
        '--test-branch', default=None,
        help="Branch to attempt to checkout before doing batch job.")
    parser.add_argument(
        '--skip-rosdep-keys',
        nargs='*',
        help="The specified rosdep keys will be ignored, i.e. not resolved "
             "and not installed.")
    parser.add_argument(
        '--build-ignore',
        nargs='*',
        help="The specified package(s) will be ignored, i.e. not built, "
             "tested, or installed.")
    parser.add_argument(
        '--depth-before', type=int, metavar='NUM_BEFORE', default=0,
        help='Number of forward-dependent packages upon which ' +
             'the targeted package(s) depends.')
    parser.add_argument(
        '--depth-after', type=int, metavar='NUM_AFTER', default=0,
        help='Number of reverse-dependent packages which ' +
             'depend upon the targeted package(s).')
    parser.add_argument(
        '--packages-select', nargs='*', metavar='PKG_NAME',
        help='Only process a subset of packages.')
    args = parser.parse_args(argv)

    debian_pkg_names = [
        'git',
        'python3-apt',
        'python3-colcon-common-extensions',
        'python3-rosdep',
        'python3-vcstool',
    ]

    # get versions for build dependencies
    apt_cache = Cache()
    debian_pkg_versions = get_binary_package_versions(
        apt_cache, debian_pkg_names)

    # generate Dockerfile
    data = {
        'os_name': args.os_name,
        'os_code_name': args.os_code_name,
        'arch': args.arch,

        'distribution_repository_urls': args.distribution_repository_urls,
        'distribution_repository_keys': get_distribution_repository_keys(
            args.distribution_repository_urls,
            args.distribution_repository_key_files),

        'rosdistro_name': args.rosdistro_name,

        'custom_rosdep_urls': [],

        'uid': get_user_id(),

        'build_environment_variables': args.env_vars,

        'dependencies': debian_pkg_names,
        'dependency_versions': debian_pkg_versions,

        'repos_file_urls': args.repos_file_urls,
        'test_branch': args.test_branch,

        'skip_rosdep_keys': args.skip_rosdep_keys,
        'build_ignore': args.build_ignore,

        'depth_before': args.depth_before,
        'depth_after': args.depth_after,
        'packages_select': args.packages_select,

        'workspace_root': args.workspace_root,
    }
    create_dockerfile(
        'ci/create_workspace.Dockerfile.em', data, args.dockerfile_dir)


if __name__ == '__main__':
    main()
