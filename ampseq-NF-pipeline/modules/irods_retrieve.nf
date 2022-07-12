process irods_retrieve {
    /**
    * Retrieves a file from iRODS.
    */

    input:
        tuple val(sample), val(irods_path), val(run_id)

    output:
        tuple val(sample), file("${output_file}"), val(run_id)

    script:
    output_file=file(irods_path).getFileName()

    """
    irods_path=$irods_path
    if [[ \$irods_path =~ \\/.*\\/.* ]]; then
        file_name=\$(basename \$irods_path)
        iget -K -f \$irods_path \$file_name
        file_md5=\$(md5sum \$file_name | awk '{print \$1}')
        irods_md5=\$(ichksum \$irods_path | awk 'NR==1 {print \$2}')
        if [[ "\$file_md5" = "\$irods_md5" ]]; then
            echo "MD5 matches"
        else
            echo "MD5 doesn't match: local file MD5 is \$file_md5, while MD5 of iRODS path is \$irods_md5"
            exit 1
        fi
    else
        echo "Given iRODS path \$irods_path does not look like a path"
        exit 1
    fi
    """
}
