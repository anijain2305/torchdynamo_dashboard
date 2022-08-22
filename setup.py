from setuptools import setup, find_packages

package_include = [
    "dashboard",
    "dashboard.*",
]

setup(
    name = 'dashboard',
    packages = find_packages(include=package_include),
)
