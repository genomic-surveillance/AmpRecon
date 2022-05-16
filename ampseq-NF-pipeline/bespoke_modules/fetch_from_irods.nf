process fetch_from_irods {
    /*
    *                                           
    */

    input:
        path(irods_path)

    output:   
        path("*.cram")

    script:
        cram_file = "${irods_path.simpleName}.cram"
        """
        mv ${irods_path} ${cram_file}
        """
}
