#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Copyright (C) 2014-2016 Harald Sitter <sitter@kde.org>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) version 3, or any
# later version accepted by the membership of KDE e.V. (or its
# successor approved by the membership of KDE e.V.), which shall
# act as a proxy defined in Section 6 of version 3 of the license.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library.  If not, see <http://www.gnu.org/licenses/>.

require_relative '../lib/ci/containment'

Docker.options[:read_timeout] = 6 * 60 * 60 # 6 hours.

DIST = ENV.fetch('DIST')
JOB_NAME = ENV.fetch('JOB_NAME')
PWD_BIND = ENV.fetch('PWD_BIND', Dir.pwd)

# TODO: transition away from compat behavior and have contain properly
#       apply pwd_bind all the time?
c = nil
if PWD_BIND != Dir.pwd # backwards compat. Behave as previosuly without pwd_bind
  c = CI::Containment.new(JOB_NAME,
                          image: CI::PangeaImage.new(:ubuntu, DIST),
                          binds: ["#{Dir.pwd}:#{PWD_BIND}"])
else
  c = CI::Containment.new(JOB_NAME, image: CI::PangeaImage.new(:ubuntu, DIST))
end

status_code = c.run(Cmd: ARGV, WorkingDir: PWD_BIND)
exit status_code
