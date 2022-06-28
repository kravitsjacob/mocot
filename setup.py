
import setuptools

with open("README.md", "r", encoding="utf-8") as fh:
    long_description = fh.read()

setuptools.setup(
    name="wc",
    version="0.0.0b0",
    author="Jacob Kravits",
    author_email="kravitsjacob@gmail.com",
    description="Multi-Objective Coordination of Thermoelectric Water Use",
    long_description=long_description,
    long_description_content_type="text/markdown",
    url="https://github.com/kravitsjacob/water-coordinate",
    project_urls={
        "Bug Tracker": "https://github.com/kravitsjacob/water-coordinate/issues",
    },
    install_requires=[
        'pandas',
    ],
    classifiers=[
        "Programming Language :: Python :: 3",
        "License :: OSI Approved :: MIT License",
        "Operating System :: OS Independent",
    ],
    package_dir={"": "src"},
    packages=setuptools.find_packages(where="src"),
    python_requires=">=3.9",
)