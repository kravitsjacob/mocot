
import setuptools

setuptools.setup(
    name="mocot",
    version="0.0.0b0",
    author="Jacob Kravits",
    author_email="kravitsjacob@gmail.com",
    description="Multi-Objective Coordination of Thermoelectric Water Use",
    url="https://github.com/kravitsjacob/water-coordinate",
    project_urls={
        "Bug Tracker": "https://github.com/kravitsjacob/water-coordinate/issues",  # noqa
    },
    install_requires=[
        'pandas',
        'tables',
        'pandapower >= 2.10.1',
        'PyYAML',
        'matpowercaseframes',
        'hiplot',
        'more_itertools',
        'seaborn',
        'matplotlib',
        # 'pygmo' TODO port project, conda install -c conda-forge pygmo
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
