# Drone Packer

A [Drone][] plugin to run [packer][] builds.

## Usage

``` yaml
pipeline:
  build:
    image: kayako/drone-packer
    include_files: [ config/common.json, config/$${name}.json ]
    target: base.json
    variables:
        name: packer
        version: 33
```

## Plugin Configuration

 - `account`: AWS account ID in which to assume the role. Instance IAM role will be used by default
 - `use_ci_role`: IAM role name to use. Defaults to `ci`. Ignored if `account` is not provided
 - `target`: Name of target packer template (without .json extension) to execute
 - `variables`: Optional variables to pass to packer build command
 - `secret_variables`: List of variables to be read from environment
 - `include_files`: List of variable files to include in build
 - `except`: List of builders to skip
 - `only`: List of builders to run

## Notes

 - `target` must be the base name of the target template. `target` can be provided as plugin parameter
   in .drone.yml file or it can be passed as deployment parameter using either drone CLI or
   github deployment api.
 - `variables` is optional and must be a flat dictionary. An intact JSON representation of the dictionary
   will be passed to packer.
 - `include_files` is an optional list of path to JSON files relative to build directory. It can contain
   `$${target}` escaped variable which will be replaced by actual target name as provided to the plugin.
 - `except` and `only`, if provided, must be valid Yaml list types.
 - `secret_variables` is an optional list of variable names that should be read from environment.
    Make sure to whitelist the secrets in drone configuration file

## Example

Following configuration

``` yaml
pipeline:
  build:
    image: kayako/drone-packer
    include_files: [ config/common.json, config/$${target} ]
    target: base.json
    variables:
        name: packer
        version: 33
    secret_variables: [ vpc_id, subnet_id ]
    secrets: [ vpc_id, subnet_id ]
```

will create a temporary file `build_variables.json` containing the variables:

``` json
{
  "name": "packer",
  "version": 33
}
```

and run the command without line breaks.

``` sh
packer build --var-file build_variables.json \
    --var-file config/common.json \
    --var-file config/base.json \
    --var 'vpc_id=vpc-id-in-env' \
    --var 'subnet_id=subnet-id-in-env' \
    base.json
```

[joshdvir/drone-ecs-deploy]: https://github.com/joshdvir/drone-ecs-deploy
[Drone]: https://docs.drone.io
