from openad.app.global_var_lib import _repo_dir
import os

c.ServerApp.ip = "0.0.0.0"
c.ServerApp.allow_origin = "*"
c.ServerApp.extra_static_paths = [os.path.join(f"{_repo_dir}/../", "gui-build-proxy")]
c.ServerApp.allow_remote_access = True
c.ServerProxy.host_allowlist = ["localhost", "127.0.0.1", "0.0.0.0"]
